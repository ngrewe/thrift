cmake_minimum_required(VERSION 2.8)
#
# This CMakeLists file is WIP. It currently works standalone to build the Cocoa
# runtime library for thrift:
#
# - On Mac OS X a framework is built
# - On other *nixes, we find the GNUstep dependencies and build a shared library
#
project(ThriftObjC)

# Compile in ARC mode
set(ThriftObjC_OBJC_FLAGS "${ThriftObjC_OBJC_FLAGS} -fobjc-arc")

# Compiler setup in the non-Apple case
if(NOT APPLE)
  # A few defines for compatibility:
  #
  # - We don't have the [SU]IntNN types, so we must use the stdint ones
  # - __nullable and __nonnull are problematic for the compiler version we
  #   target. Redefine to the newer _Nullable and _Nonnull ones
  # - Darwin specific byte-order swapping functions replaced
  set(ThriftObjC_OBJC_FLAGS
    "${ThriftObjC_OBJC_FLAGS} ${GNUSTEP_OBJC_FLAGS} \
    -fobjc-arc \
    -DSInt32=int32_t \
    -DUInt8=uint8_t \
    -DUInt32=uint32_t \
    -DSInt16=int16_t \
    -DSInt64=int64_t \
    -DUInt64=uint64_t \
    -D__nullable=_Nullable \
    -D__nonnull=_Nonnull \
    -DOSSwapLittleToHostInt64=GSSwapLittleI64ToHost \
    -DOSSwapHostToLittleInt64=GSSwapHostI64ToLittle")

  include_directories(${LIBDISPATCH_INCLUDE_DIRS})
endif()

# Set up the include directories
include_directories(
  "${CMAKE_CURRENT_SOURCE_DIR}/src"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/protocol"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/transport"
)


# The source file we share between Apple and non-Apple platforms
set(ThriftObjC_OBJC_SRCS
  src/TApplicationError.m
  src/TError.m
  src/TBaseClient.m
  src/TSharedProcessorFactory.m
  src/protocol/TBinaryProtocol.m
  src/protocol/TCompactProtocol.m
  src/protocol/TMultiplexedProtocol.m
  src/protocol/TProtocolDecorator.m
  src/protocol/TProtocolError.m
  src/protocol/TProtocolUtil.m
  src/server/TSocketServer.m
  src/transport/TFramedTransport.m
  src/transport/THTTPTransport.m
  src/transport/TMemoryBuffer.m
  src/transport/TNSFileHandleTransport.m
  src/transport/TNSStreamTransport.m
  src/transport/TTransportError.m
)

# Header files
set(ThriftObjC_HDRS
  src/TError.h
  src/TBaseClient.h
  src/TProcessor.h
  src/TProcessorFactory.h
  src/TSharedProcessorFactory.h
  src/Thrift.h
  src/protocol/TBase.h
  src/protocol/TBinaryProtocol.h
  src/protocol/TCompactProtocol.h
  src/protocol/TMultiplexedProtocol.h
  src/protocol/TProtocol.h
  src/protocol/TProtocolDecorator.h
  src/protocol/TProtocolError.h
  src/protocol/TProtocolFactory.h
  src/protocol/TProtocolUtil.h
  src/server/TSocketServer.h
  src/transport/TAsyncTransport.h
  src/transport/TFramedTransport.h
  src/transport/THTTPTransport.h
  src/transport/TMemoryBuffer.h
  src/transport/TNSFileHandleTransport.h
  src/transport/TNSStreamTransport.h
  src/transport/TTransport.h
  src/transport/TTransportError.h
)

# These are the classes not yet ported to GNUstep (because of CoreFoundation
# dependencies)
if(APPLE)
  list(APPEND ThriftObjC_OBJC_SRCS
    src/transport/TNSStreamTransport.m
    src/transport/TSocketTransport.m
    src/transport/TSSLSocketTransport.m
    src/transport/TSSLSocketTransportError.m
  )

  list(APPEND ThriftObjC_HDRS
    src/transport/TNSStreamTransport.h
    src/transport/TSocketTransport.h
    src/transport/TSSLSocketTransport.h
    src/transport/TSSLSocketTransportError.h
  )
endif()

# Assign the Objective-C compiler flags to the source files
set_source_files_properties(
  ${ThriftObjC_OBJC_SRCS}
  PROPERTIES LANGUAGE C
  COMPILE_FLAGS "${ThriftObjC_OBJC_FLAGS}"
)

# Let the user configure the name of the library (in case it clashes with
# some other language's runtime library)
set(THRIFT_RUNTIME_NAME "ThriftObjC")

# Let the user configure the include directory in order to avoid clashes with
# other languages' runtimes.
set(ThriftObjC_INCLUDE_DIRECTORY "ThriftObjC")


if(WITH_SHARED_LIB)
  if(APPLE)
	  add_library(ThriftObjC SHARED ${ThriftObjC_OBJC_SRCS}
         ${ThriftObjC_HDRS} )
  else()
	  add_library(ThriftObjC SHARED ${ThriftObjC_OBJC_SRCS} )
  endif()

  list(APPEND INSTALL_TARGETS ThriftObjC)

  if(NOT APPLE)
    # On Mac OS X, we automatically get libdispatch pulled in. On other
    # platforms we have to explicitly depend on it -- and fail if we cannot find
    # it.

	target_link_libraries(ThriftObjC ${LIBDISPATCH_LIBRARIES})
  else() # if (APPLE)

    # On Mac OS, we need to link a few more frameworks

	find_library(FOUNDATION_LIB Foundation)
	if(FOUNDATION_LIB)
	  target_link_libraries(ThriftObjC ${FOUNDATION_LIB})
	else()
	  message (SEND_ERROR "Foundation framework could not be found" )
    endif()

	find_library(SECURITY_LIB Security)
	if(SECURITY_LIB)
	  target_link_libraries(ThriftObjC ${SECURITY_LIB})
	else()
	  message (SEND_ERROR "Security framework could not be found" )
	endif()

	find_library(CORE_SERVICES_LIB CoreServices)
	if(CORE_SERVICES_LIB)
	  target_link_libraries(ThriftObjC ${CORE_SERVICES_LIB})
	else()
	  message (SEND_ERROR "CoreServices framework could not be found" )
	endif()
  endif() # if(APPLE)

  # Shared property for the library in both flavours (Apple/GNUstep)
  set_target_properties(ThriftObjC PROPERTIES
	LINKER_LANGUAGE C
	SOVERSION ${thrift_VERSION}
	OUTPUT_NAME ${THRIFT_RUNTIME_NAME}
	)

  set_property(TARGET PROPERTY NO_SONAME true)

  if(APPLE)
    # Set the information required to build a proper framework
	set_target_properties(ThriftObjC PROPERTIES
      FRAMEWORK TRUE
	  FRAMEWORK_VERSION ${thrift_VERSION}
	  PUBLIC_HEADER "${ThriftObjC_HDRS}"
	  MACOSX_FRAMEWORK_IDENTIFIER "org.apache.thrift.cocoa.rt"
	  MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${thrift_VERSION}
	  MACOSX_FRAMEWORK_BUNDLE_VERSION ${thrift_VERSION}
      MACOSX_RPATH TRUE
	)
    # Curiously enough, the build doesn't set the bundle flag on the framework.
    # We need to find the SetFile utility and do it ourselves.
	set(XC_PATHS
	  /Developer/Tools
      /Applications/Xcode.app/Contents/Developer/Tools
	  /Applications/Xcode.app/Contents/Developer/usr/bin
	  usr/bin
    )
	find_program(CMD_SETFILE SetFile ${XC_PATHS})
	if(CMD_SETFILE)
	  ADD_CUSTOM_COMMAND(TARGET ThriftObjC POST_BUILD
        COMMAND ${CMD_SETFILE} -a B ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${THRIFT_RUNTIME_NAME}.framework
        VERBATIM
      )
    endif() #if (CMD_SETFILE)
  else() #if (GNUSTEP)
    set_target_properties(ThriftObjC PROPERTIES
      LINK_FLAGS "${GNUSTEP_LINKER_FLAGS}")
  endif() #if (GNUSTEP)
endif() #if (WITH_SHARED_LIB)

if(WITH_STATIC_LIB)
  add_library(ThriftObjC-static STATIC ${ThriftObjC_OBJC_SRCS})
  set_target_properties(ThriftObjC-static PROPERTIES
	POSITION_INDEPENDENT_CODE true
	OUTPUT_NAME ${THRIFT_RUNTIME_NAME})
	list(APPEND INSTALL_TARGETS ThriftObjC-static
  )
endif()

if(APPLE)
  set(ThriftObjC_INSTALL_TYPE "NONE")
else()
   set(ThriftObjC_INSTALL_TYPE ${GNUSTEP_INSTALL_TYPE})
endif()

if(${ThriftObjC_INSTALL_TYPE} STREQUAL "NONE")
  SET(ThriftObjC_LIB_INSTALL_PATH "${LIB_INSTALL_DIR}")
  SET(ThriftObjC_HEADER_INSTALL_PATH "${INCLUDE_INSTALL_DIR}")
else()
  EXEC_PROGRAM(${GNUSTEP_CONFIG}
    ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES"
    OUTPUT_VARIABLE GNUSTEP_LIB_INSTALL_PATH)
  EXEC_PROGRAM(${GNUSTEP_CONFIG}
    ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_HEADERS"
    OUTPUT_VARIABLE GNUSTEP_HEADER_INSTALL_PATH)
  SET(ThriftObjC_LIB_INSTALL_PATH "${GNUSTEP_LIB_INSTALL_PATH}")
  SET(ThriftObjC_HEADER_INSTALL_PATH "${GNUSTEP_HEADER_INSTALL_PATH}")
endif()


if(APPLE)
  install (TARGETS ${INSTALL_TARGETS}
    LIBRARY DESTINATION ${ThriftObjC_LIB_INSTALL_PATH}
	ARCHIVE DESTINATION ${ThriftObjC_LIB_INSTALL_PATH}
	FRAMEWORK DESTINATION @rpath/Library/Frameworks
  )
else() # if (NOT APPLE)
  install(TARGETS ${INSTALL_TARGETS}
	LIBRARY DESTINATION ${ThriftObjC_LIB_INSTALL_PATH}
	ARCHIVE DESTINATION ${ThriftObjC_LIB_INSTALL_PATH})
  install(FILES ${ThriftObjC_HDRS}
  DESTINATION "${ThriftObjC_HEADER_INSTALL_PATH}/${ThriftObjC_INCLUDE_DIRECTORY}")
endif()

# uninstall target
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
  IMMEDIATE @ONLY)

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
