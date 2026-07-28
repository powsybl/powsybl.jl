# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Report
  using ..LibPowsybl

  """
      ReportNode(task_key = "", default_name = "") -> ReportNode

  A report node collects the functional logs (a tree of typed messages) produced by
  PowSyBl operations such as a network import or a load flow. Pass it to the operations
  that accept a `report_node` argument, then render it as text (`print`, `string` or
  simply displaying it) or as JSON with [`to_json`](@ref).

  `task_key` is a key identifying the root task and `default_name` its human-readable name.
  """
  mutable struct ReportNode
    handle::LibPowsybl.JavaHandle
  end

  function ReportNode(task_key::String = "", default_name::String = "")
    return ReportNode(LibPowsybl.create_report_node(task_key, default_name))
  end

  """
      to_json(report_node::ReportNode) -> String

  Render the report as JSON.
  """
  to_json(report_node::ReportNode) = String(LibPowsybl.json_report(report_node.handle))

  # Text rendering goes through show, which also makes print(report_node) and
  # string(report_node) work.
  Base.show(io::IO, report_node::ReportNode) = print(io, String(LibPowsybl.print_report(report_node.handle)))
end
