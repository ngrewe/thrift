/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import <Foundation/Foundation.h>
#import "TSocketServer.h"
#import "TNSStreamTransport.h"
#import "TProtocol.h"
#import "TTransportError.h"
#import "TProtocolError.h"

#import <sys/socket.h>
#include <netinet/in.h>

#ifdef GNUSTEP
#include <dispatch/dispatch.h>
#endif



NSString *const TSocketServerClientConnectionFinished = @"TSocketServerClientConnectionFinished";
NSString *const TSocketServerProcessorKey = @"TSocketServerProcessor";
NSString *const TSockerServerTransportKey = @"TSockerServerTransport";

@class TSocketStreamHolder;

@protocol TSocketStreamHolderDelegate <NSObject>

- (void)streamHolderDone: (TSocketStreamHolder*)holder;
@end

@interface TSocketServer () <TSocketStreamHolderDelegate>
{
#ifndef GNUSTEP
  CFSocketRef _serverSocket;
  CFRunLoopSourceRef _source;
#else

#endif
  NSTimer *housekeeping;
}
@property(strong, nonatomic) id<TProtocolFactory> inputProtocolFactory;
@property(strong, nonatomic) id<TProtocolFactory> outputProtocolFactory;
@property(strong, nonatomic) id<TProcessorFactory> processorFactory;
@property(strong, nonatomic) NSFileHandle *socketFileHandle;
@property(strong, nonatomic) dispatch_queue_t processingQueue;
@property(strong,nonatomic) NSMutableArray<TSocketStreamHolder*> *clients;

- (void) _scheduleInputStream: (NSInputStream*)iStream
                 outputStream: (NSOutputStream*)oStream;
@end

@interface TNSStreamTransport () <NSStreamDelegate>
@end


@interface TSocketStreamHolder : NSObject <NSStreamDelegate>
@property (weak, readonly) TSocketServer *server;
@property (nonatomic,readwrite) NSDate* lastUsed;
@property (nonatomic,readonly) TNSStreamTransport *transport;
@property (readwrite,getter=isProcessing) BOOL processing;
@end


@implementation TSocketStreamHolder

- (NSComparisonResult) compare: (TSocketStreamHolder*)other
{
  return [[self lastUsed] compare: [other lastUsed]];
}

- (void)closeStreamsAndNotify
{

  __weak TSocketStreamHolder* wSelf = self;
  [_transport close];
  dispatch_async(dispatch_get_main_queue(), ^{
    [_server streamHolderDone: wSelf];
  });
}

- (BOOL) checkStreamStatus
{
  __weak TSocketStreamHolder* wSelf = self;
  NSInputStream *iStream = [_transport input];
  if (([iStream streamStatus] > NSStreamStatusWriting)
    || ([iStream streamStatus] < NSStreamStatusOpening)) {
    [self closeStreamsAndNotify];
    return NO;
  }
  return YES;
}


- (void) rescheduleDelegate: (id<NSStreamDelegate>)delegate
                     onMain: (BOOL)newIsMain
{
  NSRunLoop *oldLoop = nil;
  NSRunLoop *newLoop = nil;
  if (newIsMain) {
    oldLoop = [NSRunLoop currentRunLoop];
    newLoop = [NSRunLoop mainRunLoop];
  } else {
    oldLoop = [NSRunLoop mainRunLoop];
    newLoop = [NSRunLoop currentRunLoop];
  }
  NSStream *iStream = [_transport input];
  NSStream *oStream = [_transport output];
  [iStream setDelegate: delegate];
  [iStream removeFromRunLoop: oldLoop forMode: NSDefaultRunLoopMode];
  [oStream removeFromRunLoop: oldLoop forMode: NSDefaultRunLoopMode];
  [iStream scheduleInRunLoop: newLoop forMode: NSDefaultRunLoopMode];
  [oStream scheduleInRunLoop: newLoop forMode: NSDefaultRunLoopMode];

}

- (instancetype)initWithServer: (TSocketServer*)server
                   inputStream: (NSInputStream*)iStream
                  outputStream: (NSOutputStream*)oStream
{
  if (nil == (self = [super init])) {
    return nil;
  }
  _server = server;
  _transport = [[TNSStreamTransport alloc] initWithInputStream: iStream
                                                  outputStream: oStream];
  _lastUsed = [NSDate date];
  [self rescheduleDelegate: self onMain: YES];
  return self;
}

- (void) handleMessage
{
  @autoreleasepool {
    [self rescheduleDelegate: _transport
                      onMain: NO];
    id<TProcessor> processor = [[_server processorFactory] processorForTransport: _transport];

    id <TProtocol> inProtocol = [[_server inputProtocolFactory] newProtocolOnTransport: _transport];
    id <TProtocol> outProtocol = [[_server outputProtocolFactory] newProtocolOnTransport: _transport];

    NSError *error;
    if (![processor processOnInputProtocol:inProtocol outputProtocol:outProtocol error:&error]) {
      BOOL report = YES;
      // Handle error, but ignore a failed opportunistic read
      if ([[error domain] isEqualToString: TProtocolErrorDomain]) {
        NSError *u = [[error userInfo] objectForKey: NSUnderlyingErrorKey];
        if ([[u domain] isEqualToString: TTransportErrorDomain]
          && [u code] == TTransportErrorNotOpen) {
            report = NO;
          }
      }
      if (report) {
        NSLog(@"Error processing request: %@", error);
      }
      [self closeStreamsAndNotify];
    } else if ([self checkStreamStatus]) {
        [self setLastUsed: [NSDate date]];
        [self rescheduleDelegate: self
                          onMain: YES];
      }
    dispatch_sync(dispatch_get_main_queue(), ^{
      [self setProcessing: NO];
    });
  }

}

- (void)dispatchMessage
{
  TSocketServer *s = [self server];
  if (nil == s) {
    [self closeStreamsAndNotify];
    return;
  }
  [self setProcessing: YES];
  dispatch_async([s processingQueue], ^{
     [self handleMessage];
  });
}

- (void)stream: (NSStream*)iStream handleEvent: (NSStreamEvent)event
{
  switch (event) {
    case NSStreamEventHasBytesAvailable:
      [self dispatchMessage];
      break;
    case NSStreamEventErrorOccurred:
    case NSStreamEventEndEncountered:
      [self closeStreamsAndNotify];
      break;
    default:
     //ignore
     break;
  }
}
@end



CFStringRef TCreateServerDescription(const void* retainedServer)
{
  NSString *s = [(__bridge TSocketServer*)retainedServer description];
  return (__bridge_retained CFStringRef)s;
}

void TOnSocketAcceptForLiveServer(CFSocketRef sock, CFSocketCallBackType ty,
  CFDataRef addr, const void *nativeHandlePtr, void *retainedServer)
{
  if (ty != kCFSocketAcceptCallBack) {
    return;
  }

  CFReadStreamRef iStream = NULL;
  CFWriteStreamRef oStream = NULL;
  CFStreamCreatePairWithSocket(kCFAllocatorDefault,
    *(CFSocketNativeHandle*)nativeHandlePtr, &iStream, &oStream);
  TSocketServer *server = (__bridge TSocketServer*)retainedServer;
  if (iStream && oStream) {

    CFReadStreamSetProperty(iStream, kCFStreamPropertyShouldCloseNativeSocket,
      kCFBooleanTrue);
    CFWriteStreamSetProperty(oStream, kCFStreamPropertyShouldCloseNativeSocket,
      kCFBooleanTrue);
    [server _scheduleInputStream: (__bridge_transfer NSInputStream*)iStream
                    outputStream: (__bridge_transfer NSOutputStream*)oStream];
  } else {
    NSLog(@"Error getting streams");
  }

}

@implementation TSocketServer

#ifndef GNUSTEP
- (BOOL) scheduleServerSocketOnPort:(int)port
{
  // create a socket.
  int fd = -1;
  const CFSocketContext ctx = { 0, (__bridge void*)self, NULL, NULL, TCreateServerDescription };

  CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM,
    IPPROTO_TCP, kCFSocketAcceptCallBack, TOnSocketAcceptForLiveServer, &ctx);
  if (socket) {
    fd = CFSocketGetNative(socket);
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    NSData *address = [NSData dataWithBytes:&addr length:sizeof(addr)];
    if (CFSocketSetAddress(socket, (__bridge CFDataRef)address) != kCFSocketSuccess) {
      CFSocketInvalidate(socket);
      CFRelease(socket);
      NSLog(@"TSocketServer: Could not bind to address");
      return NO;
    }
  } else {
    NSLog(@"TSocketServer: No server socket");
    return NO;
  }
  _serverSocket = socket;
  _source = CFSocketCreateRunLoopSource(
    kCFAllocatorDefault,
    _serverSocket, 0);
  CFRunLoopAddSource(
    CFRunLoopGetCurrent(),
    _source,
    kCFRunLoopDefaultMode);
  return YES;
}

- (void)deallocServerSocket
{
  CFRunLoopRemoveSource(CFRunLoopGetMain(),
    _source, kCFRunLoopDefaultMode);
  CFRelease(_source);
  CFSocketInvalidate(_serverSocket);
  CFRelease(_serverSocket);
}
#else
- (NSFileHandle* _Nullable)fileHandleForPort:(int)port
{
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);

  int fd = socket(addr.sin_family, SOCK_STREAM, IPPROTO_TCP);
  if (0 == fd) {
    NSLog(@"TSocketServer: Could not create server socket");
	return nil;
  }
  if (bind(fd, (struct sockaddr*)&addr, sizeof(struct sockaddr_in))) {
    NSLog(@"TSocketServer: Could not bind to address.");
	close(fd);
	return nil;
  }
  // backlog of 256 to match CFSocket
  if (listen(fd, 256)) {
	NSLog(@"TSocketServer: Could not listen on socket");
	close(fd);
	return nil;
  }
  return [[NSFileHandle alloc] initWithFileDescriptor: fd
									   closeOnDealloc: YES];
}
#endif

- (void)_purgeStaleConnections: (NSTimer*)t
{
  NSMutableArray<TSocketStreamHolder*>* toPurge = nil;
  NSDate *now = [NSDate date];
  for (TSocketStreamHolder *h in _clients) {
    if (![h isProcessing]
      && [now timeIntervalSinceDate: [h lastUsed]] > _connectionTimeout)
    {
      if (nil == toPurge) {
        toPurge = [NSMutableArray array];
      }
      [toPurge addObject: h];
    }
  }
  if ([toPurge count] != 0) {
    [_clients removeObjectsInArray: toPurge];
    [toPurge removeAllObjects];
  }
}

-(instancetype) initWithPort:(int)port
             protocolFactory:(id <TProtocolFactory>)protocolFactory
            processorFactory:(id <TProcessorFactory>)processorFactory;
{
  if (nil == (self = [super init])) {
    return nil;
  }
  _inputProtocolFactory = protocolFactory;
  _outputProtocolFactory = protocolFactory;
  _processorFactory = processorFactory;
  _connectionTimeout = 60.0f;
  dispatch_queue_attr_t processingQueueAttr;
#ifndef GNUSTEP
    processingQueueAttr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_BACKGROUND, 0);
#else
  processingQueueAttr = DISPATCH_QUEUE_CONCURRENT;
#endif

  _processingQueue = dispatch_queue_create("TSocketServer.processing", processingQueueAttr);
  _clients = [NSMutableArray new];
  if ([self scheduleServerSocketOnPort: port]) {
      NSLog(@"TSocketServer: Listening on TCP port %d", port);
  } else {
    self = nil;
  }
  housekeeping = [NSTimer scheduledTimerWithTimeInterval: 1.0f
                                                  target: self
                                                selector: @selector(_purgeStaleConnections:)
                                                userInfo: nil
                                                 repeats: YES];
  return self;
}



-(void) dealloc
{
  [housekeeping invalidate];
  [self deallocServerSocket];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)streamHolderDone: (TSocketStreamHolder*)holder
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [NSNotificationCenter.defaultCenter postNotificationName:TSocketServerClientConnectionFinished
                                                      object:self
                                                    userInfo:@{TSocketServerProcessorKey: [NSNull null],
                                                               TSockerServerTransportKey: [holder transport]}
    ];
  });

}

- (void) _scheduleInputStream: (NSInputStream*)iStream
                 outputStream: (NSOutputStream*)oStream
{
  [iStream open];
  [oStream open];
  TSocketStreamHolder *holder = [[TSocketStreamHolder alloc] initWithServer: self
                                                                inputStream: iStream
                                                               outputStream: oStream];
  [_clients addObject: holder];
}

@end
