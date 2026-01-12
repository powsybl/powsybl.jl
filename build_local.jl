# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using BinaryBuilder, Pkg

name = "Powsybl"
version = v"0.2.0"

pypowsybl_version = v"1.12.0"

sources = [
    DirectorySource("./cpp", target="cpp"),
    GitSource("https://github.com/powsybl/pypowsybl.git", "cfc5f6b15e31d11f1879ba01fbf9e9f8032efd0b", "cpp"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-windows.zip",
                  "467d269c52de4a3bcc73dc351f7f777357c5dda0311962b605f7262e3bde639d",
                  "powsybl-java-windows"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-linux.zip",
                  "1f9a747255405cc3c4df7dd404fb5d58fc2a9843d7932dde6129d71ab33edac9",
                  "powsybl-java-linux"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-darwin.zip",
                  "e388a8638fd9834cb6dcf1c63d1189aee380d82e92956aff055757991a0ea409",
                  "powsybl-java-darwin")
]


script = raw"""
cd $WORKSPACE/srcdir

# Get binary for powsybl-java, generated with GraalVm
if [[ "${target}" == *-mingw* ]]; then
    cp -r powsybl-java-windows/* ${prefix}
fi
if [[ "${target}" == *-linux-* ]]; then
    cp -r powsybl-java-linux/* ${prefix}
fi
if [[ "${target}" == *-apple-* ]]; then
    cp -r powsybl-java-darwin/* ${prefix}
fi

# Build powsybl-cpp API
cd $WORKSPACE/srcdir/cpp/ && mkdir build && cd build
cmake ${WORKSPACE}/srcdir/cpp/pypowsybl/cpp -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} -DBUILD_PYPOWSYBL_JAVA=OFF -DBUILD_PYTHON_BINDINGS=OFF -DPYPOWSYBL_JAVA_LIBRARY_DIR=$prefix/lib -DPYPOWSYBL_JAVA_INCLUDE_DIR=$prefix/include -DCMAKE_INSTALL_PREFIX=$prefix
cmake --build . --target install --config Release

# Build julia wrapper
cd $WORKSPACE/srcdir/ && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ../cpp/powsybljl-cpp -DJulia_PREFIX=$prefix -DJlCxx_DIR=$prefix/lib/cmake/JlCxx -DCMAKE_FIND_ROOT_PATH=$prefix -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} -DCMAKE_PREFIX_PATH=$prefix -DCMAKE_INSTALL_PREFIX=$prefix -DPOWSYBL_INSTALL_DIR=$prefix
cmake --build . --target install --config Release
"""

products = [
LibraryProduct(["math", "libmath"], :libmath)
LibraryProduct(["pypowsybl-java", "libpypowsybl-java"], :libpypowsybl_java)
LibraryProduct(["powsybl-cpp", "libpowsybl-cpp"], :libpowsybl_cpp)
LibraryProduct(["PowsyblJlWrap", "libPowsyblJlWrap"], :libPowsyblJlWrap)
]

dependencies = [
    Dependency("libcxxwrap_julia_jll"),
    Dependency("libjulia_jll")
]

platform = Platform("x86_64", "linux"; cxxstring_abi="cxx11", julia_version=v"1.12.3")

build_tarballs(ARGS, name, version, sources, script, [platform], products, dependencies;
    preferred_gcc_version=v"10")
