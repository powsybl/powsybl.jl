module Powsybl
  using CxxWrap
  using Powsybl_jll
  @wrapmodule(() -> :libPowsyblJlWrap, :define_module_powsybl)
  function __init__()
      @initcxx
      set_java_library_path(dirname(Powsybl_jll.libmath_path))
      atexit(close)
  end

  function close()
    close_powsybl()
  end
  include("Network.jl")
end