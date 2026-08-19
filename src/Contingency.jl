# Copyright (c) 2026, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Contingency
  using ..LibPowsybl

  """
  Which states a computation reports on: every one it knows about (`ALL`), the
  pre-contingency state alone (`NONE`), the given post-contingency states alone
  (`SPECIFIC`), or every post-contingency state (`ONLY_CONTINGENCIES`).
  """
  @enum ContingencyContextType begin
    ALL = LibPowsybl.CONTINGENCY_CONTEXT_ALL
    NONE = LibPowsybl.CONTINGENCY_CONTEXT_NONE
    SPECIFIC = LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC
    ONLY_CONTINGENCIES = LibPowsybl.CONTINGENCY_CONTEXT_ONLY_CONTINGENCIES
  end

  # The value the engine expects, for a module handing one to a native call.
  raw(context_type::ContingencyContextType) = LibPowsybl.ContingencyContextTypeRaw(Int(context_type))
end
