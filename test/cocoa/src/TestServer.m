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
#import "ThriftTestThriftTest.h"
#import "TProtocolFactory.h"
#import "TBinaryProtocol.h"
#import "TCompactProtocol.h"
#import "TSharedProcessorFactory.h"
#import "TSocketServer.h"
#import "TNSFileHandleTransport.h"
#include <inttypes.h>
#include <unistd.h>
#include <stdio.h>
#include <getopt.h>
#include <string.h>

#define TEST_BASETYPES     1  // 0000 0001
#define TEST_STRUCTS       2  // 0000 0010
#define TEST_CONTAINERS    4  // 0000 0100
#define TEST_EXCEPTIONS    8  // 0000 1000
#define TEST_UNKNOWN      64  // 0100 0000 (Failed to prepare environemt etc.)
#define TEST_TIMEOUT     128  // 1000 0000
#define TEST_NOTUSED      48  // 0011 0000 (reserved bits)


@interface TestHandler : NSObject <ThriftTestThriftTest>

@end

@implementation TestHandler
- (BOOL) testVoid: (NSError *__autoreleasing *)__thriftError;
{
  printf("testVoid()\n");
  return YES;
}

- (NSString *) testString: (NSString *) thing
                    error: (NSError *__autoreleasing *)__thriftError
{
    printf("testString(\"%s\")\n", [thing UTF8String]);
    return thing;
}


- (NSNumber *) testBool: (BOOL) thing
                  error: (NSError *__autoreleasing *)__thriftError
{
    printf("testBool(%s)\n", thing ? "true" : "false");
    return [NSNumber numberWithBool: thing];
}


- (NSNumber *) testByte: (SInt8) thing
                  error: (NSError *__autoreleasing *)__thriftError
{
    printf("testByte(%d)\n", (int)thing);
    return [NSNumber numberWithInteger: thing];
}

- (NSNumber *) testI32: (SInt32) thing
                 error: (NSError *__autoreleasing *)__thriftError
{
    printf("testI32(%d)\n", (int)thing);
    return [NSNumber numberWithInteger: thing];
}


- (NSNumber *) testI64: (SInt64) thing
                 error: (NSError *__autoreleasing *)__thriftError
{
    printf("testI64(%" PRId64 ")\n", thing);
    return [NSNumber numberWithInteger: thing];
}


- (NSNumber *) testDouble: (double) thing
                    error: (NSError *__autoreleasing *)__thriftError
{
    printf("testDouble(%f)\n", thing);
    return [NSNumber numberWithDouble: thing];
  }


- (NSData *) testBinary: (NSData *) thing
                  error: (NSError *__autoreleasing *)__thriftError
{
    static const char *alphabet = "0123456789ABCDEF";
    NSUInteger inLength = [thing length];
    NSUInteger inPosition = 0;
    const uint8_t* inBuf = (const uint8_t*)[thing bytes];

    NSUInteger outLength = 2 * inLength;
    NSUInteger outPosition = 0;
    char* outBuf = (char*)malloc(outLength + 1);

    if (NULL == outBuf)
    {
      if (NULL != __thriftError)
      {
        *__thriftError =
          [NSError errorWithType: TApplicationErrorInternalError
                          reason: @"Could not allocate"];
      }
      return nil;
    }

    while (inPosition < inLength)
    {
      uint8_t c = inBuf[inPosition++];
      outBuf[outPosition++] = alphabet[(c >> 4) & 0x0F];
      outBuf[outPosition++] = alphabet[c & 0x0F];
    }
    outBuf[outPosition] = '\0';
    printf("testBinary(%s)\n", outBuf);
    free(outBuf);
    return thing;
  }


- (ThriftTestXtruct *) testStruct: (ThriftTestXtruct *) thing
                            error: (NSError *__autoreleasing *)__thriftError
{
  printf("testStruct({\"%s\", %d, %d, %" PRId64 "})\n",
         [[thing string_thing] UTF8String],
         (int)[thing byte_thing],
         [thing i32_thing],
         [thing i64_thing]);
  return thing;
}

- (ThriftTestXtruct2 *) testNest: (ThriftTestXtruct2 *) nest
                           error: (NSError *__autoreleasing *)__thriftError;
{
    ThriftTestXtruct *thing = [nest struct_thing];
    printf("testNest({%d, {\"%s\", %d, %d, %" PRId64 "}, %d})\n",
           (int)[nest byte_thing],
           [[thing string_thing] UTF8String],
           (int)[thing byte_thing],
           [thing i32_thing],
           [thing i64_thing],
           [nest i32_thing]);
    return nest;
  }

- (NSDictionary<NSNumber *, NSNumber *> *) testMap: (NSDictionary<NSNumber *, NSNumber *> *) thing
                                             error: (NSError *__autoreleasing *)__thriftError
{
  char* prefix = "";
  printf("testMap({");
  for (NSNumber* num in [thing allKeys]) {
    printf("%s%d => %d", prefix, [num intValue],
      [[thing objectForKey: num] intValue]);
    prefix = ", ";
  }
  printf("})\n");
  return thing;
}

- (NSDictionary<NSString *, NSString *> *) testStringMap: (NSDictionary<NSString *, NSString *> *) thing
                                                   error: (NSError *__autoreleasing *)__thriftError
{
    char* prefix = "";
    printf("testMap({");
    for (NSString* key in [thing allKeys]) {
      printf("%s%s => %s", prefix, [key UTF8String],
        [[thing objectForKey: key] UTF8String]);
      prefix = ", ";
    }
    printf("})\n");
    return thing;
}

- (NSSet<NSNumber *> *) testSet: (NSSet<NSNumber *> *) thing
                          error: (NSError *__autoreleasing *)__thriftError
{
    char* prefix = "";
    printf("testSet({");
    for (NSNumber* num in thing) {
      printf("%s%d", prefix, [num intValue]);
      prefix = ", ";
    }
    printf("})\n");
    return thing;
}

- (NSArray<NSNumber *> *) testList: (NSArray<NSNumber *> *) thing
                             error: (NSError *__autoreleasing *)__thriftError
{
    char* prefix = "";
    printf("testList({");
    for (NSNumber* num in thing) {
        printf("%s%d", prefix, [num intValue]);
    prefix = ", ";
  }
  printf("})\n");
  return thing;
}

- (NSNumber *) testEnum: (ThriftTestNumberz) thing
                  error: (NSError *__autoreleasing *)__thriftError
{
  printf("testEnum(%d)\n", thing);
  return [NSNumber numberWithInt: thing];
}
- (NSNumber *) testTypedef: (ThriftTestUserId) thing
                     error: (NSError *__autoreleasing *)__thriftError
{
  printf("testTypedef(%" PRId64 ")\n", thing);
  return [NSNumber numberWithLongLong: thing];
}
- (NSDictionary<NSNumber*, NSDictionary<NSNumber*, NSNumber*>*>*) testMapMap: (SInt32) hello
                                                                       error: (NSError *__autoreleasing *)__thriftError
{
    NSDictionary<NSNumber*, NSDictionary<NSNumber*, NSNumber*>*>* mapmap = nil;
    NSMutableDictionary<NSNumber*, NSNumber*>* pos = [NSMutableDictionary new];
    NSMutableDictionary<NSNumber*, NSNumber*>* neg = [NSMutableDictionary new];
    printf("testMapMap(%d)\n", hello);
    for (int i = 1; i < 5; i++) {
      NSNumber *n = [NSNumber numberWithInt: i];
      NSNumber *negN = [NSNumber numberWithInt: -i];
      [pos setObject: n forKey: n];
      [neg setObject: negN forKey: negN];
    }
    mapmap = [NSDictionary dictionaryWithObjectsAndKeys:
        pos, @4, neg, @-4, nil];
    return mapmap;
}
- (NSDictionary<NSNumber *, NSDictionary<NSNumber *, ThriftTestInsanity *> *> *)
  testInsanity: (ThriftTestInsanity *) argument
         error: (NSError *__autoreleasing *)__thriftError
{
    printf("testInsanity()\n");


    ThriftTestInsanity* looney = [[ThriftTestInsanity alloc] initWithUserMap: nil
                                                                     xtructs: nil];
    NSDictionary<NSNumber*,ThriftTestInsanity*>* firstMap = @{
      @(ThriftTestNumberzTWO) : argument,
      @(ThriftTestNumberzTHREE) : argument
    };
    NSDictionary<NSNumber*,ThriftTestInsanity*>* secondMap = @{
      @(ThriftTestNumberzSIX) : looney
    };
    NSDictionary<NSNumber*, NSDictionary<NSNumber*, ThriftTestInsanity*>*>* insane = @{

      @1: firstMap,
      @2: secondMap
    };
    printf("return");
    printf(" = {");
    for (NSNumber* n in [insane allKeys]) {
      printf("%" PRId64 " => {", [n longLongValue]);
      NSDictionary<NSNumber*,ThriftTestInsanity*>* v = [insane objectForKey: n];
      for (NSNumber *n2 in [v allKeys]) {
        printf("%d => {", [n2 intValue]);
        ThriftTestInsanity* v2 = [v objectForKey: n2];
        NSDictionary<NSNumber*,NSNumber*>* userMap = [v2 userMap];

        printf("{");
        for (NSNumber *n3 in [userMap allKeys]) {
          printf("%d => %" PRId64 ", ", [n3 intValue],
            [[userMap objectForKey: n3] longLongValue]);
        }
        printf("}, ");
        NSArray<ThriftTestXtruct *>* xtructs = [v2 xtructs];
        printf("{");
        for (ThriftTestXtruct *x in xtructs) {
          printf("{\"%s\", %d, %d, %" PRId64 "}, ",
                 [[x string_thing] UTF8String],
                 (int)[x byte_thing],
                 [x i32_thing],
                 [x i64_thing]);
        }
        printf("}");

        printf("}, ");
      }
      printf("}, ");
    }
    printf("}\n");

    return insane;
  }
- (ThriftTestXtruct *) testMulti: (SInt8) arg0
                            arg1: (SInt32) arg1
                            arg2: (SInt64) arg2
                            arg3: (NSDictionary<NSNumber *, NSString *> *) arg3
                            arg4: (ThriftTestNumberz) arg4
                            arg5: (ThriftTestUserId) arg5
                            error: (NSError *__autoreleasing *)__thriftError
{


    printf("testMulti()\n");
    return [[ThriftTestXtruct alloc] initWithString_thing: @"Hello2"
                                               byte_thing: arg0
                                                i32_thing: arg1
                                                i64_thing: arg2];
  }

- (BOOL) testException: (NSString *) arg
                 error: (NSError *__autoreleasing *)__thriftError
{
    printf("testException(%s)\n", [arg UTF8String]);
    if ([arg isEqualToString: @"Xception"])
    {
      if (NULL != __thriftError) {
        *__thriftError = [[ThriftTestXception alloc] initWithErrorCode: 1001
                                                               message: arg];
      }
      return NO;
    } else if ([arg isEqualToString: @"TException"]) {
      if (NULL != __thriftError) {
        *__thriftError = [NSError errorWithType: TApplicationErrorUnknown
                                         reason: @""];
      }
      return NO;
    }
    return YES;
}

- (ThriftTestXtruct *) testMultiException: (NSString *) arg0
                                     arg1: (NSString *) arg1
                                    error: (NSError *__autoreleasing *)__thriftError
{
  printf("testMultiException(%s, %s)\n", [arg0 UTF8String], [arg1 UTF8String]);
  ThriftTestXtruct* struct_thing = nil;

  if ([arg0 isEqualToString: @"Xception"])
  {
    if (NULL != __thriftError) {
      *__thriftError = [[ThriftTestXception alloc] initWithErrorCode: 1001
                                                             message: @"This is an Xception"];
    }
    return nil;
  } else if ([arg0 isEqualToString: @"Xception2"]) {
    if (NULL != __thriftError) {
      struct_thing =
      [[ThriftTestXtruct alloc] initWithString_thing: @"This is an Xception2"
                                          byte_thing: 0
                                           i32_thing: 0
                                           i64_thing: 0];
      *__thriftError =
        [[ThriftTestXception2 alloc] initWithErrorCode: 2002
                                          struct_thing: struct_thing];
      return nil;
    }
  }
  struct_thing =
  [[ThriftTestXtruct alloc] initWithString_thing: arg1
                                      byte_thing: 0
                                       i32_thing: 0
                                       i64_thing: 0];
  return struct_thing;
}


- (BOOL) testOneway: (SInt32) secondsToSleep
              error: (NSError *__autoreleasing *)__thriftError
{
  printf("testOneway(%d): Sleeping...\n", secondsToSleep);
  sleep(MAX(0,secondsToSleep));
  printf("testOneway(%d): done sleeping!\n", secondsToSleep);
  return YES;
}

@end

static NSString* kGetOptLongDomain = @"ThriftTestGetOptLongDomain";

static uint16_t _uint16FromDefaults(NSUserDefaults* dflts, NSString *key)
{
  NSInteger val = 0;
  NSNumber *n =
    [[dflts volatileDomainForName: kGetOptLongDomain] objectForKey: key];
  if (nil != n) {
      val = [n integerValue];
      if (val < 0 || val > UINT16_MAX) {
        val = 0;
      }
  }
  if (val == 0) {
    val = [dflts integerForKey: key];
  }
  return val;
}

static BOOL _boolFromDefaults(NSUserDefaults* dflts, NSString *key)
{
  NSNumber *n =
    [[dflts volatileDomainForName: kGetOptLongDomain] objectForKey: key];
  if (nil != n) {
    return [n boolValue];
  }
  return [dflts boolForKey: key];
}

static NSString* _stringFromDefaults(NSUserDefaults* dflts, NSString *key)
{
  NSString *s =
    [[dflts volatileDomainForName: kGetOptLongDomain] objectForKey: key];
  if (nil != s) {
    return s;
  }
  return [dflts stringForKey: key];
}


NSDictionary<NSString*,Class>* _protocolFactories;
NSDictionary<NSString*,Class>* _servers;
NSDictionary<NSString*,Class>* _transports;

@interface ServerFactory : NSObject
+ (id)serverFromDefaults;
@end

@implementation ServerFactory

+ (void)initialize
{
  if (self == [ServerFactory class]) {
    _protocolFactories = @{
      @"binary": [TBinaryProtocolFactory class],
      @"compact": [TCompactProtocolFactory class]
    };
    _servers = @{
      @"simple": [TSocketServer class]
    };
    _transports = @{
      @"buffered": [TNSFileHandleTransport class]
    };
  }
}

+ (id)serverFromDefaults
{
  NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
  uint16_t port = _uint16FromDefaults(dflts, @"port");
  NSString *server = _stringFromDefaults(dflts, @"server-type");
  NSString *transport = _stringFromDefaults(dflts, @"transport");
  NSString *protocol = _stringFromDefaults(dflts, @"protocol");

  Class srvClass = [_servers objectForKey: server];
  Class tClass = [_transports objectForKey: transport];
  Class pClass = [_protocolFactories objectForKey: protocol];
  if (Nil == srvClass) {
    [NSException raise: NSGenericException
                format: @"Invalid server type '%@'", server];
  }
  if (Nil == tClass) {
    [NSException raise: NSGenericException
                format: @"Invalid transport '%@'", transport];
  }
  if (Nil == pClass) {

    [NSException raise: NSGenericException
                format: @"Invalid protocol '%@'", protocol];

  }
  ThriftTestThriftTestProcessor *processor  =
    [[ThriftTestThriftTestProcessor alloc] initWithThriftTest:
      [TestHandler new]];
  TSharedProcessorFactory *procFactory =
    [[TSharedProcessorFactory alloc] initWithSharedProcessor: processor];
  id<TProtocolFactory> protoFactory = [pClass sharedFactory];
  return [[srvClass alloc] initWithPort: port
                   protocolFactory: protoFactory
                  processorFactory: procFactory];
}


@end

#define OPT_CHAR_HELP 'h'


/**
 * NSUserDefaults has weird options parsing (only single dash arguments), so
 * we drop down to getopt_long() for this task and set up a volatile domain
 * with the results. The return value of this function indicates whether we
 * should just print help.
 */
static BOOL
_addVolatileDomainFromGetOptLong(int argc, char** argv) {
  int c = 0;
  NSMutableDictionary *values = [NSMutableDictionary new];
  while (1) {
    static struct option opts[] = {
      {"help", no_argument, 0, OPT_CHAR_HELP},
      {"port", required_argument, 0, 0},
      {"domain-socket", required_argument, 0, 0},
      {"abstract-namespace", optional_argument, 0, 0},
      {"server-type", required_argument, 0, 0},
      {"transport", required_argument, 0, 0},
      {"protocol", required_argument, 0, 0},
      {0, 0, 0, 0}
    };
    int idx = 0;
    c = getopt_long(argc, argv, "h", opts, &idx);
    if (c == -1) {
        break;
    }

    switch (c) {
      case OPT_CHAR_HELP:
        return YES;
      case 0:
        if (idx == 3) {
          NSNumber *v = @YES;
          if (optarg != NULL) {
            char abstract = *optarg;
            if (NULL == strchr("yYTt123456789", abstract)) {
              v = @NO;
            }
          }
          [values setObject: v
                     forKey: @( opts[idx].name )];
        } else if (idx == 1) {
          int v = atoi(optarg);
          if ((v > 0) && (v < UINT16_MAX)) {
            [values setObject: @( v )
                       forKey: @( opts[idx].name )];
          }

        } else {
          [values setObject: @(optarg)
                     forKey: @( opts[idx].name )];
        }
      case -1:
        break;
      case ':':
      case '?':
      default:
        continue;
    }
  }
  [[NSUserDefaults standardUserDefaults] setVolatileDomain: values
                                                   forName: kGetOptLongDomain];
  return NO;
}



int main(int argc, char** argv) {

  @autoreleasepool {
    NSUserDefaults *dflts = [NSUserDefaults standardUserDefaults];
    [dflts registerDefaults: @{
      @"port": @9090,
      @"domain-socket": @"",
      @"abstract-namespace": @NO,
      @"server-type": @"simple",
      @"transport": @"buffered",
      @"protocol": @"binary"
    }];
    if (_addVolatileDomainFromGetOptLong(argc, argv)) {
      printf("TODO: Print help\n");
      return 0;
    }

    id server = nil;
    @try {
      server = [ServerFactory serverFromDefaults];
    } @catch (NSException *e) {
      fprintf(stderr, "Could not create server: %s\n", [[e reason] UTF8String]);
    }
    if (server == nil) {
      return TEST_UNKNOWN;
    }
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (1) {
      @autoreleasepool {
        [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01f]];
      }
    }
  }
  return 0;
}
