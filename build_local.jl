# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using BinaryBuilder, Pkg

name = "Powsybl"
version = v"0.4.0"

pypowsybl_version = v"1.15.0"

sources = [
    DirectorySource("./cpp", target="cpp"),
    GitSource("https://github.com/powsybl/pypowsybl.git", "5d246382efcc24edf568ffd4577c53fe4508bee3", "cpp"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-windows.zip",
                  "35b7865333d53bb7f60952a2d56f23b43b74996d2a747b209e10439dbce52171",
                  "powsybl-java-windows"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-linux.zip",
                  "3fb02f30c74043b05ae9fb527e42ae0072f7cdb0e0924aeca3820182f9402a48",
                  "powsybl-java-linux"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-darwin.zip",
                  "9afda0a27e34ba628bcba9c48a88e0a456df362ba7da7c2d9fdce649debec963",
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
