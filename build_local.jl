# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using BinaryBuilder, Pkg

name = "Powsybl"
version = v"0.1.0"

julia_versions = [VERSION]

platform = HostPlatform()

pypowsybl_version = v"1.7.0"

sources = [
    DirectorySource("./cpp", target="cpp"),
    GitSource("https://github.com/powsybl/pypowsybl.git", "cd5fea41bbfb2897fd71a6e63b2d07a465055699", "cpp"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-windows.zip",
                  "82d3cee44992dcceaee7549f17351155e91c9eb2bdce97b1cf6c0107155991e8",
                  "powsybl-java-windows"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-linux.zip",
                  "8832e1ff432e97807dc6dfddb4b001dd2c3c05a7411fc3748c8af3854a3b448c",
                  "powsybl-java-linux"),
    ArchiveSource("https://github.com/powsybl/pypowsybl/releases/download/v$(pypowsybl_version)/binaries-v$(pypowsybl_version)-darwin.zip",
                  "d541eb07a334d9272b167cb30f7d846ff109db49ac61a9776593c1aface18324",
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

build_tarballs(ARGS, name, version, sources, script, [platform], products, dependencies;
    preferred_gcc_version=v"10", julia_compat="1.6")
