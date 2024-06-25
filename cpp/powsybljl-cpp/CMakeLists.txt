cmake_minimum_required(VERSION 3.21)
project(PowsyblJlWrap)

set(CMAKE_CXX_STANDARD 17)

set(CMAKE_MACOSX_RPATH 1)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")


#---Find JlCxx package-------------------------------------------------------------
find_package(JlCxx)
get_target_property(JlCxx_location JlCxx::cxxwrap_julia LOCATION)
get_filename_component(JlCxx_location ${JlCxx_location} DIRECTORY)
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib;${JlCxx_location}")
message(STATUS "Found JlCxx at ${JlCxx_location}")
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)

set(CXXWRAP_INCLUDE_DIR "../libcxxwrap-julia/include")
set(POWSYBL_CPP_INCLUDE_DIR ${POWSYBL_INSTALL_DIR}/include/powsybl-cpp)

message(>>${POWSYBL_CPP_INCLUDE_DIR})

include_directories(${CXXWRAP_INCLUDE_DIR} ${Julia_INCLUDE_DIRS} ${POWSYBL_CPP_INCLUDE_DIR})
link_directories(${POWSYBL_INSTALL_DIR}/lib)

add_library(PowsyblJlWrap SHARED powsybl_jl.cpp)
target_link_libraries(PowsyblJlWrap PUBLIC JlCxx::cxxwrap_julia JlCxx::cxxwrap_julia_stl powsybl-cpp)

install(TARGETS PowsyblJlWrap)