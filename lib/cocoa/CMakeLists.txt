cmake_minimum_required(VERSION 2.8)
#
# This CMakeLists file is WIP. It currently works standalone to build the Cocoa
# runtime library for thrift:
#
# - On Mac OS X a framework is built
# - On other *nixes, we find the GNUstep dependencies and build a shared library
#
project(ThriftRuntime)

# Compile in ARC mode
set(ThriftRuntime_OBJC_FLAGS "${ThriftRuntime_OBJC_FLAGS} -fobjc-arc")

# Compiler setup in the non-Apple case
if(NOT APPLE)
# gnustep-config is a wrapper around make that can emit configuration
# information for building Objective-C apps.
find_program(GNUSTEP_CONFIG gnustep-config)

  if(GNUSTEP_CONFIG)
    # First step is to get the Objective-C compiler flags
	EXEC_PROGRAM(gnustep-config
	  ARGS "--objc-flags"
	  OUTPUT_VARIABLE ThriftRuntime_OBJC_FLAGS)
    else()
      message( WARNING
      "gnustep-config not found you might have to set appropriate CMAKE_C_FLAGS")
  endif()
  # A few defines for compatibility:
  #
  # - We don't have the [SU]IntNN types, so we must use the stdint ones
  # - __nullable and __nonnull are problematic for the compiler version we
  #   target. Redefine to the newer _Nullable and _Nonnull ones
  # - Darwin specific byte-order swapping functions replaced
  set(ThriftRuntime_OBJC_FLAGS "${ThriftRuntime_OBJC_FLAGS} -fobjc-arc \
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
endif()

# Set up the include directories
# TODO: When we hook into the main project file, ${PROJECT_SOURCE_DIR} changes
# and these need to be adapted to fit.
include_directories(
  "${PROJECT_SOURCE_DIR}/src"
  "${PROJECT_SOURCE_DIR}/src/protocol"
  "${PROJECT_SOURCE_DIR}/src/transport"
)

# The version of the library
# TODO: Get from parent CMakeLists
set(ThriftRuntime_VERSION 1.0.0)

# The source file we share between Apple and non-Apple platforms
set(ThriftRuntime_OBJC_SRCS
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
  src/transport/TTransportError.m
)

# Header files
set(ThriftRuntime_HDRS
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
  src/transport/TTransport.h
  src/transport/TTransportError.h
)

# These are the classes not yet ported to GNUstep (because of CoreFoundation
# dependencies)
if(APPLE)
  list(APPEND ThriftRuntime_OBJC_SRCS
    src/transport/TNSStreamTransport.m
    src/transport/TSocketTransport.m
    src/transport/TSSLSocketTransport.m
    src/transport/TSSLSocketTransportError.m
  )

  list(APPEND ThriftRuntime_HDRS
    src/transport/TNSStreamTransport.h
    src/transport/TSocketTransport.h
    src/transport/TSSLSocketTransport.h
    src/transport/TSSLSocketTransportError.h
  )
endif()

# Assign the Objective-C compiler flags to the source files
set_source_files_properties(
  ${ThriftRuntime_OBJC_SRCS}
  PROPERTIES LANGUAGE C
  COMPILE_FLAGS "${ThriftRuntime_OBJC_FLAGS}"
)

# Let the user configure the name of the library (in case it clashes with
# some other language's runtime library)
set(THRIFT_RUNTIME_NAME "ThriftRuntime" CACHE STRING
    "Name of the Thrift runtime library (e.g. ThriftRuntime for libThriftRuntime)")

# Let the user configure the include directory in order to avoid clashes with
# other languages' runtimes.
set(INCLUDE_DIRECTORY "ThriftRuntime" CACHE STRING
    "Subdirectory of the include path to install the headers.")


# TODO: When we inherit from the parent, we no longer need to set this ourselves
set(WITH_SHARED_LIB true CACHE BOOL
  "Build the shared version of the Thrift runtime")

if(WITH_SHARED_LIB)
  if(APPLE)
	  add_library(ThriftRuntime SHARED ${ThriftRuntime_OBJC_SRCS}
         ${ThriftRuntime_HDRS} )
  else()
	  add_library(ThriftRuntime SHARED ${ThriftRuntime_OBJC_SRCS} )
  endif()

  list(APPEND INSTALL_TARGETS ThriftRuntime)

  if(NOT APPLE)
    # On Mac OS X, we automatically get libdispatch pulled in. On other
    # platforms we have to explicitly depend on it -- and fail if we cannot find
    # it.
    find_library(LIBDISPATCH dispatch)
    if(LIBDISPATCH)
	  target_link_libraries(ThriftRuntime ${LIBDISPATCH})
    else()
	  message( SEND_ERROR "libdispatch could not be found" )
    endif()

    # If we have GNUstep config, we can use it to pull all other linker flags
    # we might need
    if(GNUSTEP_CONFIG)
	  EXEC_PROGRAM(gnustep-config
		  ARGS "--objc-libs"
	  OUTPUT_VARIABLE ThriftRuntime_LINK_FLAGS)

	  EXEC_PROGRAM(gnustep-config
		  ARGS "--base-libs"
	  OUTPUT_VARIABLE ThriftRuntime_LINK_FLAGS)
    else()
      # If we don't have it, we can try to find our dependencies
	  message( WARNING "gnustep-config not found you might have to set appropriate CMAKE_SHARED_LINKER_FLAGS")
	  # Link libobjc
	  find_library(LIBOBJC objc)
	  if(LIBOBJC)
		target_link_libraries(ThriftRuntime ${LIBOBJC})
	  else()
		message( SEND_ERROR "Objective-C runtime could not be found" )
	  endif()

	  # Link gnustep-base
	  find_library(GS_BASE gnustep-base)
	  if (GS_BASE)
		target_link_libraries(ThriftRuntime ${GS_BASE})
	  else()
		message( SEND_ERROR "GNUstep base could not be found" )
	  endif()
    endif()
  else() # if (APPLE)

    # On Mac OS, we need to link a few more frameworks

	find_library(FOUNDATION_LIB Foundation)
	if(FOUNDATION_LIB)
	  target_link_libraries(ThriftRuntime ${FOUNDATION_LIB})
	else()
	  message (SEND_ERROR "Foundation framework could not be found" )
    endif()

	find_library(SECURITY_LIB Security)
	if(SECURITY_LIB)
	  target_link_libraries(ThriftRuntime ${SECURITY_LIB})
	else()
	  message (SEND_ERROR "Security framework could not be found" )
	endif()

	find_library(CORE_SERVICES_LIB CoreServices)
	if(CORE_SERVICES_LIB)
	  target_link_libraries(ThriftRuntime ${CORE_SERVICES_LIB})
	else()
	  message (SEND_ERROR "CoreServices framework could not be found" )
	endif()
  endif() # if(APPLE)

  # Shared property for the library in both flavours (Apple/GNUstep)
  set_target_properties(ThriftRuntime PROPERTIES
	LINKER_LANGUAGE C
	SOVERSION ${ThriftRuntime_VERSION}
	OUTPUT_NAME ${THRIFT_RUNTIME_NAME}
	LINK_FLAGS "${ThriftRuntime_LINK_FLAGS}"
	)

  set_property(TARGET PROPERTY NO_SONAME true)

  if(APPLE)
    # Set the information required to build a proper framework
	set_target_properties(ThriftRuntime PROPERTIES
      FRAMEWORK TRUE
	  FRAMEWORK_VERSION ${ThriftRuntime_VERSION}
	  PUBLIC_HEADER "${ThriftRuntime_HDRS}"
	  MACOSX_FRAMEWORK_IDENTIFIER "org.apache.thrift.cocoa.rt"
	  MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${ThriftRuntime_VERSION}
	  MACOSX_FRAMEWORK_BUNDLE_VERSION ${ThriftRuntime_VERSION}
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
	  ADD_CUSTOM_COMMAND(TARGET ThriftRuntime POST_BUILD
        COMMAND ${CMD_SETFILE} -a B ${CMAKE_CURRENT_BINARY_DIR}/${THRIFT_RUNTIME_NAME}.framework
        VERBATIM
      )
    endif() #if (CMD_SETFILE)
  endif() #if (APPLE)
endif() #if (WITH_SHARED_LIB)

# TODO: This doens't need to be set once we depend on the parent CMakeLists
set(WITH_STATIC_LIB true CACHE BOOL
  "Build the static version of the ThriftRuntime runtime")
if(WITH_STATIC_LIB)
  add_library(ThriftRuntime-static STATIC ${ThriftRuntime_OBJC_SRCS})
  set_target_properties(ThriftRuntime-static PROPERTIES
	POSITION_INDEPENDENT_CODE true
	OUTPUT_NAME ${THRIFT_RUNTIME_NAME})
	list(APPEND INSTALL_TARGETS ThriftRuntime-static
  )
endif()



#
# For installation, we can try to find the custom location were GNUstep wants
# us to install libraries. This portion is adapted from libobjc2's CMakeLists
# file.
#
if(GNUSTEP_CONFIG)
  EXEC_PROGRAM(gnustep-config
	ARGS "--installation-domain-for=ThriftRuntime"
	OUTPUT_VARIABLE DEFAULT_INSTALL_TYPE)
endif()


# but if we don't and install location, we don't care and install into default
# locations.
if(NOT DEFAULT_INSTALL_TYPE)
  set(DEFAULT_INSTALL_TYPE "NONE")
endif()

if (NOT CMAKE_INSTALL_LIBDIR)
	set(CMAKE_INSTALL_LIBDIR lib)
endif()

# People can override this
set(GNUSTEP_INSTALL_TYPE ${DEFAULT_INSTALL_TYPE} CACHE STRING
  "GNUstep installation type.  Options are NONE, SYSTEM, NETWORK or LOCAL.")
if(${GNUSTEP_INSTALL_TYPE} STREQUAL "NONE")
  SET(LIB_INSTALL_PATH "${CMAKE_INSTALL_LIBDIR}" CACHE STRING
	"Subdirectory of the root prefix where libraries are installed.")
  SET(HEADER_INSTALL_PATH "include")
else()
  EXEC_PROGRAM(gnustep-config
	ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES"
	OUTPUT_VARIABLE LIB_INSTALL_PATH
  )
  EXEC_PROGRAM(gnustep-config
	ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_HEADERS"
	OUTPUT_VARIABLE HEADER_INSTALL_PATH
  )
endif()

if(NOT ${GNUSTEP_INSTALL_TYPE} STREQUAL "NONE")
  message(STATUS "GNUstep install type set to ${GNUSTEP_INSTALL_TYPE}")
endif()

if(APPLE)
  install (TARGETS ${INSTALL_TARGETS}
    LIBRARY DESTINATION ${LIB_INSTALL_PATH}
	ARCHIVE DESTINATION ${LIB_INSTALL_PATH}
	FRAMEWORK DESTINATION @rpath/Library/Frameworks
  )
else() # if (NOT APPLE)
  install(TARGETS ${INSTALL_TARGETS}
	LIBRARY DESTINATION ${LIB_INSTALL_PATH}
	ARCHIVE DESTINATION ${LIB_INSTALL_PATH})
  install(FILES ${Thrift_HDRS}
	DESTINATION "${HEADER_INSTALL_PATH}/${INCLUDE_DIRECTORY}")
endif()

# uninstall target
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
  IMMEDIATE @ONLY)

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
