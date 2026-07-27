# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using Powsybl
using Test

# To avoid reading potential user specific configuration
Powsybl.LibPowsybl.set_config_read(false)

@testset "Test network data" begin
  network = Powsybl.Network.create_ieee9()

  @test network.id == "ieee9cdf"
  @test network.name == "ieee9cdf"
  @test network.source_format == "IEEE-CDF"
  @test network.forecast_distance == 0
  @test network.case_date ≈ 1.240704e9

  lines = Powsybl.Network.get_lines(network)
  @test names(lines) == ["id", "name", "r", "x", "g1", "b1", "g2", "b2", "p1", "q1", "i1", "p2", "q2",
   "i2", "voltage_level1_id", "voltage_level2_id", "bus1_id", "bus2_id", "connected1", "connected2"]

  @test lines[:, "id"] == ["L7-8-0", "L9-8-0", "L7-5-0", "L9-6-0", "L5-4-0", "L6-4-0"]
  @test lines[:, "bus1_id"] == ["VL2_1", "VL3_1", "VL2_1", "VL3_1", "VL5_0", "VL6_0"]
end

@testset "Test network save and load" begin
  network = Powsybl.Network.load("simple-eu.xiidm")
  @test network.name == "simple-eu"

  Powsybl.Network.save(network, "simple-eu.mat", "MATPOWER")
  network_matpower = Powsybl.Network.load("simple-eu.mat")
  @test network_matpower.name == "simple-eu"

  Powsybl.Network.save(network, "simple-eu.zip", "CGMES")
  network_cgmes = Powsybl.Network.load("simple-eu.zip")
  @test network_cgmes.name == "urn:uuid:simple-eu_N_EQUIPMENT_2024-09-25T12:47:58Z_1_1D__FM"
end

@testset "Test load flow parameters" begin
  parameters = Powsybl.LoadFlow.load_flow_parameters()
  @test parameters.voltage_init_mode == Powsybl.LoadFlow.UNIFORM_VALUES
  @test parameters.transformer_voltage_control_on == false
  @test parameters.use_reactive_limits == true
  @test parameters.phase_shifter_regulation_on == false
  @test parameters.twt_split_shunt_admittance == false
  @test parameters.shunt_compensator_voltage_control_on == false
  @test parameters.read_slack_bus == true
  @test parameters.write_slack_bus == true
  @test parameters.distributed_slack == true
  @test parameters.balance_type == Powsybl.LoadFlow.PROPORTIONAL_TO_GENERATION_P_MAX
  @test parameters.dc_use_transformer_ratio == true
  @test parameters.countries_to_balance == []
  @test parameters.component_mode == Powsybl.LoadFlow.MAIN_CONNECTED
  @test parameters.dc_power_factor == 1.0
  @test parameters.provider_parameters == Dict{String, String}()
end

@testset "Test AC load flow" begin
  network = Powsybl.Network.create_ieee9()
  parameters = Powsybl.LoadFlow.load_flow_parameters()
  result = Powsybl.LoadFlow.run_ac(network, parameters)

  component_res = result.component_results[1, :]
  @test component_res.connected_component_num == 0
  @test component_res.synchronous_component_num == 0
  @test component_res.status == Powsybl.LoadFlow.CONVERGED
  @test component_res.status_text == "Converged"
  @test component_res.iteration_count == 3
  @test component_res.reference_bus_id == "VL1_0"
  @test component_res.distributed_active_power == 0.0

  slackbus_res = result.slack_bus_results[1, :]
  @test slackbus_res.connected_component_num == 0
  @test slackbus_res.synchronous_component_num == 0
  @test slackbus_res.id == "VL1_0"
  @test isapprox(slackbus_res.active_power_mismatch, -4.324e-6; atol = 1e-3)
end

@testset "Test DC load flow" begin
  network = Powsybl.Network.create_ieee9()
  parameters = Powsybl.LoadFlow.load_flow_parameters()
  result = Powsybl.LoadFlow.run_dc(network, parameters)
  @test size(result.component_results, 1) == 1
end

@testset "Test version table" begin
  table = Powsybl.get_version_table()
  @test table isa String
  @test !isempty(table)
end

@testset "Test import/export format metadata" begin
  extensions = Powsybl.Network.get_network_import_supported_extensions()
  @test extensions isa Vector{String}
  @test !isempty(extensions)

  cgmes_import = Powsybl.Network.get_import_parameters("CGMES")
  @test size(cgmes_import, 2) >= 1

  xiidm_export = Powsybl.Network.get_export_parameters("XIIDM")
  @test size(xiidm_export, 2) >= 1
end

@testset "Test variant management" begin
  network = Powsybl.Network.create_ieee9()

  variants = Powsybl.Network.get_variants_ids(network)
  @test length(variants) == 1

  initial = Powsybl.Network.get_working_variant_id(network)
  @test initial in variants

  Powsybl.Network.clone_variant(network, initial, "my_variant")
  @test "my_variant" in Powsybl.Network.get_variants_ids(network)

  Powsybl.Network.set_working_variant(network, "my_variant")
  @test Powsybl.Network.get_working_variant_id(network) == "my_variant"

  Powsybl.Network.set_working_variant(network, initial)
  Powsybl.Network.remove_variant(network, "my_variant")
  @test !("my_variant" in Powsybl.Network.get_variants_ids(network))
end

@testset "Test network mutation" begin
  network = Powsybl.Network.create_ieee9()

  loads_before = Powsybl.Network.get_loads(network)
  n_before = size(loads_before, 1)
  @test n_before > 0

  a_load = loads_before[1, "id"]
  Powsybl.Network.remove_elements(network, a_load)
  @test size(Powsybl.Network.get_loads(network), 1) == n_before - 1

  generator_ids = Powsybl.Network.get_elements_ids(network, Powsybl.LibPowsybl.GENERATOR)
  @test generator_ids isa Vector{String}
  @test !isempty(generator_ids)
end

@testset "Test bus/breaker view" begin
  network = Powsybl.Network.create_ieee9()
  voltage_levels = Powsybl.Network.get_voltage_levels(network)
  vl_id = voltage_levels[1, "id"]

  buses = Powsybl.Network.get_bus_breaker_view_buses(network, vl_id)
  @test size(buses, 1) >= 1

  Powsybl.Network.get_bus_breaker_view_switches(network, vl_id)
  Powsybl.Network.get_bus_breaker_view_elements(network, vl_id)
end

@testset "Test node/breaker view and connectable status" begin
  network = Powsybl.Network.create_four_substations_node_breaker()
  voltage_levels = Powsybl.Network.get_voltage_levels(network)
  vl_id = voltage_levels[1, "id"]

  nodes = Powsybl.Network.get_node_breaker_view_nodes(network, vl_id)
  @test size(nodes, 1) >= 1

  Powsybl.Network.get_node_breaker_view_switches(network, vl_id)
  Powsybl.Network.get_node_breaker_view_internal_connections(network, vl_id)

  loads = Powsybl.Network.get_loads(network)
  if size(loads, 1) > 0
    load_id = loads[1, "id"]
    @test Powsybl.Network.update_connectable_status(network, load_id, false) isa Bool
    @test Powsybl.Network.update_connectable_status(network, load_id, true) isa Bool
  end
end
