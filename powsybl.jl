module Powsybl
  using CxxWrap
  library_path = joinpath(@__DIR__, "install/bin")
  @wrapmodule(() -> joinpath(library_path, "PowsyblJlWrap"), :define_module_powsybl)
    function __init__()
      @initcxx
      set_java_library_path(library_path)
  end
end