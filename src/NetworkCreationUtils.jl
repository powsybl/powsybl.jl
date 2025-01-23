# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

function _create_network(name::String, network_id::String = "")
  handle = Powsybl.create_network(name, network_id)
  return Network.NetworkHandle(handle,
    Powsybl.id(handle),
    Powsybl.name(handle),
    Powsybl.source_format(handle),
    Powsybl.forecast_distance(handle),
    Powsybl.case_date(handle))
end

function create_empty(network_id::String = "")
  return _create_network("empty", network_id)
end

function create_ieee9(network_id::String = "")
  return _create_network("ieee9", network_id)
end

function create_ieee14(network_id::String = "")
  return _create_network("ieee14", network_id)
end

function create_ieee30(network_id::String = "")
  return _create_network("ieee30", network_id)
end

function create_ieee57(network_id::String = "")
  return _create_network("ieee57", network_id)
end

function create_ieee118(network_id::String = "")
  return _create_network("ieee118", network_id)
end

function create_ieee300(network_id::String = "")
  return _create_network("ieee300", network_id)
end

function create_eurostag_tutorial_example1(network_id::String = "")
  return _create_network("eurostag_tutorial_example1", network_id)
end

function create_eurostag_tutorial_example1_with_power_limits(network_id::String = "")
  return _create_network("eurostag_tutorial_example1_with_power_limits", network_id)
end

function create_four_substations_node_breaker(network_id::String = "")
  return _create_network("four_substations_node_breaker", network_id)
end

function create_four_substations_node_breaker_with_extensions(network_id::String = "")
  return _create_network("four_substations_node_breaker_with_extensions", network_id)
end

function create_micro_grid_be(network_id::String = "")
  return _create_network("micro_grid_be", network_id)
end

function create_micro_grid_nl(network_id::String = "")
  return _create_network("micro_grid_nl", network_id)
end

function create_metrix_tutorial_six_buses(network_id::String = "")
  return _create_network("metrix_tutorial_six_buses", network_id)
end