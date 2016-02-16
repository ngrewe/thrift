# find GNUstep
#
# Usage:
# GNUSTEP_CONFIG: Where to find the configuration utility
# GNUSTEP_OBJC_FLAGS: Compiler flags for compiling Objective-C code
# GNUSTEP_LINKER_FLAGS: Linker flags for linking Objective-C code
# GNUSTEP_INSTALL_TYPE: The GNUstep installation domain to use. NONE or LOCAL
# is best for most people.
#
# GNUstep_FOUND, If false, we can't build the Objective-C library

set(GNUstep_EXTRA_PREFIXES /usr/local /opt/local "$ENV{HOME}" )
find_program(GNUSTEP_CONFIG gnustep-config
  PATHS ${GNUstep_EXTRA_PREFIXES}
  DOC "Location of the gnustep-config utility"
)




if(GNUSTEP_CONFIG)

  EXEC_PROGRAM(${GNUSTEP_CONFIG}
    ARGS "--objc-libs"
    OUTPUT_VARIABLE GS_OBJC_LINKER_FLAGS)

  EXEC_PROGRAM(gnustep-config
    ARGS "--objc-flags"
    OUTPUT_VARIABLE GS_DEFAULT_OBJC_FLAGS)

  EXEC_PROGRAM(gnustep-config
    ARGS "--base-libs"
    OUTPUT_VARIABLE GS_BASE_LINKER_FLAGS)

  set(GS_DEFAULT_LINKER_FLAGS "${GS_OBJC_LINKER_FLAGS} ${GS_BASE_LINKER_FLAGS}")
  EXEC_PROGRAM(gnustep-config
    ARGS "--installation-domain-for=ThriftRuntime"
    OUTPUT_VARIABLE GS_DEFAULT_INSTALL_TYPE)

  EXEC_PROGRAM(gnustep-config
  	ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES"
  	OUTPUT_VARIABLE GNUSTEP_LIB_INSTALL_PATH)

  EXEC_PROGRAM(gnustep-config
  	ARGS "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_HEADERS"
  	OUTPUT_VARIABLE GNUSTEP_HEADER_INSTALL_PATH)

endif()

if(NOT GS_DEFAULT_INSTALL_TYPE)
  set(GS_DEFAULT_INSTALL_TYPE "NONE")
endif()

set(GNUSTEP_OBJC_FLAGS ${GS_DEFAULT_OBJC_FLAGS} CACHE STRING
  "Compiler flags for compiling Objective-C code")
set(GNUSTEP_LINKER_FLAGS ${GS_DEFAULT_LINKER_FLAGS} CACHE STRING
  "Linker flags for linking Objective-C code")
set(GNUSTEP_INSTALL_TYPE ${GS_DEFAULT_INSTALL_TYPE} CACHE STRING
  "GNUstep installation type.  Options are NONE, SYSTEM, NETWORK or LOCAL.")


if (GNUSTEP_OBJC_FLAGS AND GNUSTEP_LINKER_FLAGS)
  set(GNUstep_FOUND TRUE)
else ()
  set(GNUstep_FOUND FALSE)
endif ()

if (GNUstep_FOUND)
  if (NOT GNUstep_FIND_QUIETLY)
    message(STATUS "Found GNUstep installation")
  endif ()
else ()
if (GNUstep_FIND_REQUIRED)
    message(FATAL_ERROR "Could NOT find GNUstep.")
  endif ()
  message(STATUS "GNUstep NOT found.")
endif ()

mark_as_advanced(
    GNUSTEP_INSTALL_TYPE
    GNUSTEP_CONFIG
    GNUSTEP_LINKER_FLAGS
    GNUSTEP_OBJC_FLAGS
  )
