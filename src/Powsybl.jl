# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Powsybl
  include("LibPowsybl.jl")
  include("Network.jl")
  include("LoadFlow.jl")

  """
      get_version_table() -> String

  Return an ASCII table listing the versions of all the underlying PowSyBl modules
  bundled in `Powsybl_jll`. Useful to report the exact PowSyBl core / provider versions
  in use when filing an issue.
  """
  function get_version_table()
    return String(LibPowsybl.get_version_table())
  end
end