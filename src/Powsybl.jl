# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Powsybl
  using CxxWrap
  using Powsybl_jll
  @wrapmodule(() -> :libPowsyblJlWrap, :define_module_powsybl)
  function __init__()
      @initcxx
      set_java_library_path(dirname(Powsybl_jll.libmath_path))
      atexit(close)
  end

  function dict_to_string_string_map(input_dict::Dict{String, String})::Powsybl.StringStringMap
      map = Powsybl.StringStringMap()
      for (key, value) in input_dict
        Powsybl.put_element(map, key, value)
      end
      return map
  end

  function close()
    close_powsybl()
  end
  include("Network.jl")
end