# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

cmake_minimum_required(VERSION 3.21)
project(PowsyblJlWrap)

set(CMAKE_MACOSX_RPATH 1)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(CMAKE_INSTALL_RPATH "$ORIGIN/")

#---Find JlCxx package-------------------------------------------------------------
find_package(JlCxx)
get_target_property(JlCxx_location JlCxx::cxxwrap_julia LOCATION)
get_filename_component(JlCxx_location ${JlCxx_location} DIRECTORY)
message(STATUS "Found JlCxx at ${JlCxx_location}")
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)

set(CMAKE_CXX_STANDARD 17)

set(POWSYBL_CPP_INCLUDE_DIR ${POWSYBL_INSTALL_DIR}/include/powsybl-cpp)

include_directories(${Julia_INCLUDE_DIRS} ${POWSYBL_CPP_INCLUDE_DIR})
link_directories(${POWSYBL_INSTALL_DIR}/lib)

add_library(PowsyblJlWrap SHARED powsybl_jl.cpp)
target_link_libraries(PowsyblJlWrap PUBLIC JlCxx::cxxwrap_julia JlCxx::cxxwrap_julia_stl powsybl-cpp)
set_property(TARGET PowsyblJlWrap PROPERTY CXX_STANDARD 17)

install(TARGETS PowsyblJlWrap)