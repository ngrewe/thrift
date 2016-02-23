#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

# Contains the thrift specific LINK_AGAINST_THRIFT_LIBRARY
include(ThriftMacros)


#Make sure gen-cocoa files can be included
include_directories("${CMAKE_CURRENT_BINARY_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/gen-cocoa"
  "${PROJECT_SOURCE_DIR}/lib/cocoa/src"
  "${PROJECT_SOURCE_DIR}/lib/cocoa/src/protocol"
  "${PROJECT_SOURCE_DIR}/lib/cocoa/src/server"
  "${PROJECT_SOURCE_DIR}/lib/cocoa/src/transport"
)

set(crosstestgencocoa_SOURCES
    gen-cocoa/ThriftTestThriftTest.m
)

set_source_files_properties(
  ${crosstestgencocoa_SOURCES}
	  PROPERTIES LANGUAGE C
	    COMPILE_FLAGS "-x objective-c ${ThriftObjC_OBJC_FLAGS} -fobjc-arc "
		)


add_library(crosstestgencocoa STATIC ${crosstestgencocoa_SOURCES})
LINK_AGAINST_THRIFT_LIBRARY(crosstestgencocoa ThriftObjC)

add_executable(TestServerObjC src/TestServer.m)
target_link_libraries(TestServerObjC crosstestgencocoa)
LINK_AGAINST_THRIFT_LIBRARY(TestServerObjC ThriftObjC)
#LINK_AGAINST_THRIFT_LIBRARY(TestServer thrift)
#LINK_AGAINST_THRIFT_LIBRARY(TestServer thriftnb)
#LINK_AGAINST_THRIFT_LIBRARY(TestServer thriftz)

#add_executable(TestClient src/TestClient.cpp)
#target_link_libraries(TestClient crosstestgencpp ${Boost_LIBRARIES} ${LIBEVENT_LIB})
#LINK_AGAINST_THRIFT_LIBRARY(TestClient thrift)
#LINK_AGAINST_THRIFT_LIBRARY(TestClient thriftnb)
#LINK_AGAINST_THRIFT_LIBRARY(TestClient thriftz)

#
# Common thrift code generation rules
#

add_custom_command(OUTPUT gen-cocoa/ThriftTestThriftTest.m
    COMMAND ${THRIFT_COMPILER} --gen cocoa -r ${PROJECT_SOURCE_DIR}/test/ThriftTest.thrift
)
