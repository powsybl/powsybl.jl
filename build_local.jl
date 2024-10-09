using BinaryBuilder, Pkg

name = "Powsybl"
version = v"0.1.0"
sources = [
    DirectorySource("./cpp", target="cpp")
]

julia_versions = [VERSION]

platform = HostPlatform()

@info string("Downloading pypowsybl java binaries for ", platform.tags["os"])
if platform.tags["os"] == "linux"
    Base.download("https://github.com/powsybl/pypowsybl/releases/download/v1.7.0/binaries-v1.7.0-linux.zip", "cpp/powsybl-java.zip")
elseif  platform.tags["os"] == "windows"
    Base.download("https://github.com/powsybl/pypowsybl/releases/download/v1.7.0/binaries-v1.7.0-windows.zip", "cpp/powsybl-java.zip")
elseif platform.tags["os"] == "macos"
    Base.download("https://github.com/powsybl/pypowsybl/releases/download/v1.7.0/binaries-v1.7.0-darwin.zip", "cpp/powsybl-java.zip")
else
    throw("Unsupported platform with os " * platform.tags["os"])
end


script = raw"""
cd $WORKSPACE/srcdir

# Get binary for powsybl-java, generated with GraalVm
unzip cpp/powsybl-java.zip -d $prefix

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
    preferred_gcc_version=v"12", julia_compat="1.6")
