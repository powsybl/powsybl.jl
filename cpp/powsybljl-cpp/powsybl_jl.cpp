#include <string>

#include "jlcxx/jlcxx.hpp"
#include "powsybl-cpp.h"

JLCXX_MODULE define_module_powsybl(jlcxx::Module& mod)
{
  auto preJavaCall = [](pypowsybl::GraalVmGuard* guard, exception_handler* exc){ };
  auto postJavaCall = [](){ };
  pypowsybl::init(preJavaCall, postJavaCall);

  mod.method("get_version_table", &pypowsybl::getVersionTable, "Get an ASCII table with all PowSybBl modules version");
  mod.method("set_java_library_path", [] (std::string const& path) {
        pypowsybl::setJavaLibraryPath(path);
  }, "Set java.library.path JVM property");
}
