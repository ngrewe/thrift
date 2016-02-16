# find LibDispatch
#
# Usage:
# LIBDISPATCH_INCLUDE_DIRS, where to find LibDispatch headers
# LIBDISPATCH_LIBRARIES, LibDispatch libraries
# Libdispatch_FOUND, If false, do not try to use libdispatch

set(LIBDISPATCH_ROOT CACHE PATH "Root directory of libdispatch installation")
set(LibDispatch_EXTRA_PREFIXES /usr/local /opt/local "$ENV{HOME}" ${LIBDISPATCH_ROOT})
foreach(prefix ${LibDispatch_EXTRA_PREFIXES})
  list(APPEND LibDispatch_INCLUDE_PATHS "${prefix}/include")
  list(APPEND LibDispatch_LIBRARIES_PATHS "${prefix}/lib")
endforeach()

find_path(LIBDISPATCH_INCLUDE_DIRS dispatch/dispatch.h PATHS ${LibDispatch_INCLUDE_PATHS})
# "lib" prefix is needed on Windows
find_library(LIBDISPATCH_LIBRARIES NAMES dispatch libdispatch PATHS ${LibDispatch_LIBRARIES_PATHS})

if (LIBDISPATCH_LIBRARIES AND LIBDISPATCH_INCLUDE_DIRS)
  set(Libdispatch_FOUND TRUE)
  set(LIBDISPATCH_LIBRARIES ${LIBDISPATCH_LIBRARIES})
else ()
  set(Libdispatch_FOUND FALSE)
endif ()

if (Libdispatch_FOUND)
  if (NOT Libdispatch_FIND_QUIETLY)
    message(STATUS "Found libdispatch: ${LIBDISPATCH_LIBRARIES}")
  endif ()
else ()
  if (LibDispatch_FIND_REQUIRED)
    message(FATAL_ERROR "Could NOT find libdispatch.")
  endif ()
  message(STATUS "libdispatch NOT found.")
endif ()

mark_as_advanced(
    LIBDISPATCH_LIBRARIES
    LIBDISPATCH_INCLUDE_DIRS
  )
