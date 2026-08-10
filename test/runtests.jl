# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using Powsybl
using Test
using DataFrames

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
  @test parameters.hvdc_ac_emulation == true
  @test parameters.dc_power_factor == 1.0
  @test parameters.dc == false
  @test parameters.provider_parameters == Dict{String, String}()
end

@testset "Test the calculation kind overrides the dc parameter" begin
  LF = Powsybl.LoadFlow

  # run_ac and run_dc each impose their own calculation kind, so the dc field of the
  # parameters they are given does not decide it
  ac_reference = LF.run_ac(Powsybl.Network.create_ieee9(), LF.load_flow_parameters())
  dc_reference = LF.run_dc(Powsybl.Network.create_ieee9(), LF.load_flow_parameters())
  @test ac_reference.component_results[1, "iteration_count"] !=
        dc_reference.component_results[1, "iteration_count"]

  asking_for_dc = LF.load_flow_parameters()
  asking_for_dc.dc = true
  @test LF.run_ac(Powsybl.Network.create_ieee9(), asking_for_dc).component_results[1, "iteration_count"] ==
        ac_reference.component_results[1, "iteration_count"]

  asking_for_ac = LF.load_flow_parameters()
  asking_for_ac.dc = false
  @test LF.run_dc(Powsybl.Network.create_ieee9(), asking_for_ac).component_results[1, "iteration_count"] ==
        dc_reference.component_results[1, "iteration_count"]
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

@testset "Test element creation and update" begin
  network = Powsybl.Network.create_empty()

  Powsybl.Network.create_substations(network; id = "S1", country = "FR")
  Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                                        topology_kind = "BUS_BREAKER", nominal_v = 400.0)
  Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")
  Powsybl.Network.create_loads(network; id = "LOAD1", voltage_level_id = "VL1", bus_id = "B1",
                               p0 = 100.0, q0 = 10.0)
  Powsybl.Network.create_generators(network; id = "GEN1", voltage_level_id = "VL1", bus_id = "B1",
                                    target_p = 100.0, min_p = 0.0, max_p = 1000.0,
                                    target_v = 400.0, voltage_regulator_on = true)

  substations = Powsybl.Network.get_substations(network)
  @test "S1" in substations[:, "id"]

  loads = Powsybl.Network.get_loads(network)
  @test "LOAD1" in loads[:, "id"]
  load_row = findfirst(==("LOAD1"), loads[:, "id"])
  @test loads[load_row, "p0"] == 100.0

  generators = Powsybl.Network.get_generators(network)
  @test "GEN1" in generators[:, "id"]

  # Update an existing element
  Powsybl.Network.update_loads(network; id = "LOAD1", p0 = 200.0)
  loads = Powsybl.Network.get_loads(network)
  load_row = findfirst(==("LOAD1"), loads[:, "id"])
  @test loads[load_row, "p0"] == 200.0

  # Create several elements in a single call
  Powsybl.Network.create_buses(network; id = ["B2", "B3"], voltage_level_id = ["VL1", "VL1"])
  buses = Powsybl.Network.get_bus_breaker_view_buses(network)
  @test "B2" in buses[:, "id"]
  @test "B3" in buses[:, "id"]
end

@testset "Test element creation validation" begin
  network = Powsybl.Network.create_empty()
  Powsybl.Network.create_substations(network; id = "S1", country = "FR")
  Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                                        topology_kind = "BUS_BREAKER", nominal_v = 400.0)
  Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")

  # A column the schema does not declare is rejected rather than silently forwarded
  @test_throws ArgumentError Powsybl.Network.create_loads(network; id = "L", voltage_level_id = "VL1",
                                                          bus_id = "B1", p0 = 1.0, nonexistent_column = 1.0)
  # ... including on update
  @test_throws ArgumentError Powsybl.Network.update_loads(network; id = "L", nonexistent_column = 1.0)

  # The index column identifies the rows, so it is required
  @test_throws ArgumentError Powsybl.Network.create_loads(network; voltage_level_id = "VL1",
                                                          bus_id = "B1", p0 = 1.0, q0 = 1.0)

  # Mismatched column lengths are still rejected
  @test_throws ArgumentError Powsybl.Network.create_buses(network; id = ["B2", "B3", "B4"],
                                                          voltage_level_id = ["VL1", "VL1"])

  # As in pypowsybl, a scalar is a column of one row and is not stretched to match a
  # longer one: every argument of a call must have the same number of values
  @test_throws ArgumentError Powsybl.Network.create_buses(network; id = ["B2", "B3"],
                                                          voltage_level_id = "VL1")
  @test_throws ArgumentError Powsybl.Network.create_buses(network; id = ["B2", "B3"],
                                                          voltage_level_id = ["VL1"])

  # An argument left at nothing counts as not given, so it neither adds a column nor
  # takes part in that size check
  Powsybl.Network.create_buses(network; id = ["B2", "B3"],
                               voltage_level_id = ["VL1", "VL1"], name = nothing)
  buses = Powsybl.Network.get_bus_breaker_view_buses(network)
  @test "B2" in buses[:, "id"]
  @test "B3" in buses[:, "id"]
end

@testset "Test DataFrame input for creation and update" begin
  network = Powsybl.Network.create_empty()
  Powsybl.Network.create_substations(network; id = "S1", country = "FR")
  Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                                        topology_kind = "BUS_BREAKER", nominal_v = 400.0)
  Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")

  # Create from a DataFrame instead of keyword arguments
  loads_df = DataFrame(id = ["LOAD1", "LOAD2"], voltage_level_id = ["VL1", "VL1"],
                       bus_id = ["B1", "B1"], p0 = [100.0, 200.0], q0 = [10.0, 20.0])
  Powsybl.Network.create_loads(network, loads_df)
  loads = Powsybl.Network.get_loads(network)
  @test "LOAD1" in loads[:, "id"]
  @test "LOAD2" in loads[:, "id"]

  # Round trip: read a table, change it, write it straight back
  loads = Powsybl.Network.get_loads(network)
  update_df = DataFrame(id = loads[:, "id"], p0 = loads[:, "p0"] .* 2)
  Powsybl.Network.update_loads(network, update_df)
  loads = Powsybl.Network.get_loads(network)
  row = findfirst(==("LOAD1"), loads[:, "id"])
  @test loads[row, "p0"] == 200.0

  # The data comes either as a DataFrame or as keyword arguments, never both
  @test_throws ArgumentError Powsybl.Network.create_loads(network, loads_df; p0 = 1.0)
  @test_throws ArgumentError Powsybl.Network.update_loads(network, update_df; p0 = 1.0)
end

@testset "Test boundary line creation with its generation part" begin
  network = Powsybl.Network.create_empty()
  Powsybl.Network.create_substations(network; id = "S1", country = "FR")
  Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                                        topology_kind = "BUS_BREAKER", nominal_v = 400.0)
  Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")

  # Without a generation part: the second dataframe is sent empty
  Powsybl.Network.create_boundary_lines(network; id = "BL1", voltage_level_id = "VL1", bus_id = "B1",
                                        p0 = 10.0, q0 = 3.0, r = 0.1, x = 1.0, g = 0.0, b = 0.0)
  boundary_lines = Powsybl.Network.get_boundary_lines(network)
  @test "BL1" in boundary_lines[:, "id"]

  # With a generation part, carried by the second creation dataframe
  Powsybl.Network.create_boundary_lines(network; id = "BL2", voltage_level_id = "VL1", bus_id = "B1",
                                        p0 = 10.0, q0 = 3.0, r = 0.1, x = 1.0, g = 0.0, b = 0.0,
                                        generation = (id = "BL2", min_p = 0.0, max_p = 100.0,
                                                      target_p = 50.0, target_q = 10.0,
                                                      target_v = 400.0, voltage_regulator_on = true))
  boundary_lines = Powsybl.Network.get_boundary_lines(network)
  @test "BL2" in boundary_lines[:, "id"]

  generation = Powsybl.Network.get_boundary_lines_generation(network)
  row = findfirst(==("BL2"), generation[:, "id"])
  @test row !== nothing
  @test generation[row, "target_p"] == 50.0
  @test generation[row, "max_p"] == 100.0
end

@testset "Test extension creation, update and removal" begin
  @test "activePowerControl" in Powsybl.Network.get_extensions_names()
  @test size(Powsybl.Network.get_extensions_information(), 1) >= 1

  network = Powsybl.Network.create_eurostag_tutorial_example1()
  generator_id = Powsybl.Network.get_generators(network)[1, "id"]

  # Create an activePowerControl extension on the generator
  Powsybl.Network.create_extensions(network, "activePowerControl";
                                    id = generator_id, droop = 4.0, participate = true)
  extension = Powsybl.Network.get_extensions(network, "activePowerControl")
  @test generator_id in extension[:, "id"]
  row = findfirst(==(generator_id), extension[:, "id"])
  @test extension[row, "droop"] == 4.0
  @test extension[row, "participate"] == true          # exercises the boolean marshalling

  # Update it
  Powsybl.Network.update_extensions(network, "activePowerControl"; id = generator_id, droop = 8.0)
  extension = Powsybl.Network.get_extensions(network, "activePowerControl")
  row = findfirst(==(generator_id), extension[:, "id"])
  @test extension[row, "droop"] == 8.0

  # Remove it
  Powsybl.Network.remove_extensions(network, "activePowerControl", generator_id)
  extension = Powsybl.Network.get_extensions(network, "activePowerControl")
  @test !(generator_id in extension[:, "id"])
end

@testset "Test multi-dataframe creation (shunts and tap changers)" begin
  network = Powsybl.Network.create_empty()
  Powsybl.Network.create_substations(network; id = "S1", country = "FR")
  Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                                        topology_kind = "BUS_BREAKER", nominal_v = 400.0)
  Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")

  # Linear shunt: dataframe 0 (shunt) + dataframe 1 (linear model), dataframe 2 left empty
  Powsybl.Network.create_shunt_compensators(network;
      id = "SHUNT_L", voltage_level_id = "VL1", bus_id = "B1", section_count = 1, model_type = "LINEAR",
      linear = (id = "SHUNT_L", g_per_section = 0.0, b_per_section = 1e-5, max_section_count = 1))
  @test "SHUNT_L" in Powsybl.Network.get_shunt_compensators(network)[:, "id"]

  # Non-linear shunt with two sections: dataframe 0 + empty dataframe 1 + dataframe 2
  Powsybl.Network.create_shunt_compensators(network;
      id = "SHUNT_NL", voltage_level_id = "VL1", bus_id = "B1", section_count = 1, model_type = "NON_LINEAR",
      non_linear = (id = ["SHUNT_NL", "SHUNT_NL"], g = [0.0, 0.0], b = [1e-5, 2e-5]))
  @test "SHUNT_NL" in Powsybl.Network.get_shunt_compensators(network)[:, "id"]
  sections = Powsybl.Network.get_non_linear_shunt_compensator_sections(network)
  @test count(==("SHUNT_NL"), sections[:, "id"]) == 2

  # Ratio tap changer with three steps on an existing transformer: dataframe 0 + steps
  eurostag = Powsybl.Network.create_eurostag_tutorial_example1()
  Powsybl.Network.create_ratio_tap_changers(eurostag;
      id = "NGEN_NHV1", tap = 1, low_tap = 0, target_v = 400.0, target_deadband = 0.0, regulating = false,
      steps = (id = ["NGEN_NHV1", "NGEN_NHV1", "NGEN_NHV1"],
               g = [0.0, 0.0, 0.0], b = [0.0, 0.0, 0.0], r = [0.0, 0.0, 0.0], x = [0.0, 0.0, 0.0],
               rho = [0.9, 1.0, 1.1]))
  @test "NGEN_NHV1" in Powsybl.Network.get_ratio_tap_changers(eurostag)[:, "id"]
  rtc_steps = Powsybl.Network.get_ratio_tap_changer_steps(eurostag)
  @test count(==("NGEN_NHV1"), rtc_steps[:, "id"]) == 3
end

@testset "Test modification enum values come from the binding" begin
  N = Powsybl.Network
  L = Powsybl.LibPowsybl

  # The enum members must track the C enums rather than repeat their values, so that a
  # renumbering upstream cannot silently apply a different modification.
  @test Int(N.VOLTAGE_LEVEL_TOPOLOGY_CREATION) == Int(L.VOLTAGE_LEVEL_TOPOLOGY_CREATION)
  @test Int(N.CREATE_FEEDER_BAY) == Int(L.CREATE_FEEDER_BAY)
  @test Int(N.REPLACE_TEE_POINT_BY_VOLTAGE_LEVEL_ON_LINE) == Int(L.REPLACE_TEE_POINT_BY_VOLTAGE_LEVEL_ON_LINE)
  @test Int(N.REMOVE_FEEDER) == Int(L.REMOVE_FEEDER)
  @test Int(N.REMOVE_HVDC_LINE) == Int(L.REMOVE_HVDC_LINE)

  # Every member of each enum is distinct and contiguous from zero
  @test [Int(x) for x in instances(N.NetworkModificationType)] == collect(0:9)
  @test [Int(x) for x in instances(N.RemoveModificationType)] == collect(0:2)
end

@testset "Test network modifications" begin
  N = Powsybl.Network

  # Build a node-breaker voltage level and create its topology (two busbar sections)
  network = N.create_empty()
  N.create_substations(network; id = "S1", country = "FR")
  N.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                          topology_kind = "NODE_BREAKER", nominal_v = 400.0)
  N.create_voltage_level_topology(network; id = "VL1",
                                  aligned_buses_or_busbar_count = 2, section_count = 1, switch_kinds = "")
  busbars = N.get_busbar_sections(network)[:, "id"]
  @test length(busbars) == 2

  # Couple the two busbar sections; a coupling device adds switches
  switches_before = size(N.get_switches(network), 1)
  N.create_coupling_device(network;
                           bus_or_busbar_section_id_1 = busbars[1],
                           bus_or_busbar_section_id_2 = busbars[2], switch_prefix_id = "cpl")
  @test size(N.get_switches(network), 1) > switches_before

  # Unused connectable order positions around a busbar section
  interval = N.get_unused_order_positions_after(network, busbars[1])
  @test interval === nothing || (interval isa Tuple{Int, Int} && interval[1] <= interval[2])

  # Tap an existing line with a new line (create line on line)
  eurostag = N.create_eurostag_tutorial_example1()
  target_bus = N.get_bus_breaker_view_buses(eurostag)[1, "id"]
  N.create_line_on_line(eurostag;
                        bbs_or_bus_id = target_bus, new_line_id = "NEW_LINE",
                        new_line_r = 1.0, new_line_x = 1.0,
                        new_line_b1 = 0.0, new_line_b2 = 0.0, new_line_g1 = 0.0, new_line_g2 = 0.0,
                        line_id = "NHV1_NHV2_1", line1_id = "L1_PART1", line2_id = "L1_PART2",
                        position_percent = 50.0)
  lines_after = N.get_lines(eurostag)[:, "id"]
  @test "NEW_LINE" in lines_after
  @test "L1_PART1" in lines_after && "L1_PART2" in lines_after
  @test !("NHV1_NHV2_1" in lines_after)   # the tapped line was split

  # Remove a feeder bay (a generator and its bay)
  eurostag2 = N.create_eurostag_tutorial_example1()
  @test "GEN" in N.get_generators(eurostag2)[:, "id"]
  N.remove_feeder_bays(eurostag2, "GEN")
  @test !("GEN" in N.get_generators(eurostag2)[:, "id"])
end
@testset "Test multi-dataframe feeder bays" begin
  N = Powsybl.Network

  function node_breaker_network()
    network = N.create_empty()
    N.create_substations(network; id = "S1", country = "FR")
    N.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                            topology_kind = "NODE_BREAKER", nominal_v = 400.0)
    N.create_voltage_level_topology(network; id = "VL1", aligned_buses_or_busbar_count = 1,
                                    section_count = 1, switch_kinds = "")
    return network, N.get_busbar_sections(network)[1, "id"]
  end

  # A shunt compensator bay is described by three dataframes: the shunt, its linear model
  # and its non-linear sections. The extra ones are given as column sets.
  network, busbar = node_breaker_network()
  N.create_shunt_compensator_bay(network; id = "SHUNT1", section_count = 1,
                                 model_type = "LINEAR", target_deadband = 2.0,
                                 column_sets = Any[(id = "SHUNT1", g_per_section = 0.0,
                                                    b_per_section = 1e-5, max_section_count = 1)],
                                 bus_or_busbar_section_id = busbar, position_order = 30,
                                 direction = "BOTTOM")
  @test "SHUNT1" in N.get_shunt_compensators(network)[:, "id"]
  @test count(==("SHUNT1"), N.get_linear_shunt_compensator_sections(network)[:, "id"]) == 1

  # A boundary line bay is two dataframes, the line and its generation part
  network, busbar = node_breaker_network()
  N.create_boundary_line_bay(network; id = "BL1", p0 = 10.0, q0 = 3.0,
                             r = 0.1, x = 1.0, g = 0.0, b = 0.0,
                             column_sets = Any[(id = "BL1", min_p = 0.0, max_p = 100.0,
                                                target_p = 50.0, target_q = 10.0,
                                                target_v = 400.0, voltage_regulator_on = true)],
                             bus_or_busbar_section_id = busbar, position_order = 40,
                             direction = "BOTTOM")
  @test "BL1" in N.get_boundary_lines(network)[:, "id"]
  generation = N.get_boundary_lines_generation(network)
  @test count(==("BL1"), generation[:, "id"]) == 1
  @test generation[findfirst(==("BL1"), generation[:, "id"]), "target_p"] == 50.0

  # The extra dataframes may be left out, the element then being created on its own
  network, busbar = node_breaker_network()
  N.create_boundary_line_bay(network; id = "BL2", p0 = 10.0, q0 = 3.0,
                             r = 0.1, x = 1.0, g = 0.0, b = 0.0,
                             bus_or_busbar_section_id = busbar, position_order = 50,
                             direction = "TOP")
  @test "BL2" in N.get_boundary_lines(network)[:, "id"]
end

@testset "Test feeder bays and alias/internal-connection removal" begin
  N = Powsybl.Network

  # A helper node-breaker network with two voltage levels, each with one busbar section
  function node_breaker_network()
    network = N.create_empty()
    N.create_substations(network; id = "S1", country = "FR")
    N.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                            topology_kind = "NODE_BREAKER", nominal_v = 400.0)
    N.create_voltage_levels(network; id = "VL2", substation_id = "S1",
                            topology_kind = "NODE_BREAKER", nominal_v = 400.0)
    N.create_voltage_level_topology(network; id = "VL1", aligned_buses_or_busbar_count = 1,
                                    section_count = 1, switch_kinds = "")
    N.create_voltage_level_topology(network; id = "VL2", aligned_buses_or_busbar_count = 1,
                                    section_count = 1, switch_kinds = "")
    return network, N.get_busbar_sections(network)[:, "id"]
  end

  # Injection feeder bays (create the element and its connection bay in one step)
  network, busbars = node_breaker_network()
  N.create_load_bay(network; id = "LOAD1", p0 = 100.0, q0 = 10.0,
                    bus_or_busbar_section_id = busbars[1], position_order = 10, direction = "BOTTOM")
  @test "LOAD1" in N.get_loads(network)[:, "id"]

  N.create_generator_bay(network; id = "GEN1", max_p = 1000.0, min_p = 0.0, target_p = 100.0,
                         target_v = 400.0, voltage_regulator_on = true,
                         bus_or_busbar_section_id = busbars[1], position_order = 20, direction = "TOP")
  @test "GEN1" in N.get_generators(network)[:, "id"]

  # Several bays in one call, every column given as a vector
  N.create_load_bay(network; id = ["LOAD2", "LOAD3"], p0 = [10.0, 20.0], q0 = [1.0, 2.0],
                    bus_or_busbar_section_id = [busbars[1], busbars[2]],
                    position_order = [30, 30], direction = ["TOP", "TOP"])
  @test issubset(["LOAD2", "LOAD3"], N.get_loads(network)[:, "id"])

  # Line feeder bay (connects two node-breaker voltage levels)
  network2, busbars2 = node_breaker_network()
  N.create_line_bays(network2; id = "NEW_LINE", r = 1.0, x = 10.0, b1 = 0.0, b2 = 0.0, g1 = 0.0, g2 = 0.0,
                     bus_or_busbar_section_id_1 = busbars2[1], bus_or_busbar_section_id_2 = busbars2[2],
                     position_order_1 = 10, position_order_2 = 10)
  @test "NEW_LINE" in N.get_lines(network2)[:, "id"]

  # Two windings transformer feeder bay
  network3, busbars3 = node_breaker_network()
  N.create_2_windings_transformer_bays(network3; id = "NEW_TWT",
                                       voltage_level1_id = "VL1", voltage_level2_id = "VL2",
                                       r = 1.0, x = 10.0, g = 0.0, b = 0.0, rated_u1 = 400.0, rated_u2 = 400.0,
                                       bus_or_busbar_section_id_1 = busbars3[1], bus_or_busbar_section_id_2 = busbars3[2],
                                       position_order_1 = 10, position_order_2 = 10)
  @test "NEW_TWT" in N.get_2_windings_transformers(network3)[:, "id"]

  # Alias removal round-trip: add an alias, remove it, then the id is free to reuse
  eurostag = N.create_eurostag_tutorial_example1()
  N.create_elements(eurostag, Powsybl.LibPowsybl.ALIAS; id = "GEN", alias = "MY_ALIAS", alias_type = "")
  N.remove_aliases(eurostag; id = "GEN", alias = "MY_ALIAS")
  # Re-adding the same alias only succeeds because the previous one was removed
  N.create_elements(eurostag, Powsybl.LibPowsybl.ALIAS; id = "GEN", alias = "MY_ALIAS", alias_type = "")
  @test "GEN" in N.get_generators(eurostag)[:, "id"]

  # Internal-connection removal reaches the engine: removing a nonexistent one is rejected
  empty_nb = N.create_empty()
  N.create_substations(empty_nb; id = "S1", country = "FR")
  N.create_voltage_levels(empty_nb; id = "VL1", substation_id = "S1",
                          topology_kind = "NODE_BREAKER", nominal_v = 400.0)
  @test_throws Exception N.remove_internal_connections(empty_nb; voltage_level_id = "VL1", node1 = 0, node2 = 1)
end

@testset "Test DataFrame input for network modifications" begin
  N = Powsybl.Network

  function node_breaker_network()
    network = N.create_empty()
    N.create_substations(network; id = "S1", country = "FR")
    N.create_voltage_levels(network, DataFrame(id = ["VL1", "VL2"], substation_id = ["S1", "S1"],
                                               topology_kind = ["NODE_BREAKER", "NODE_BREAKER"],
                                               nominal_v = [400.0, 400.0]))
    # Both voltage levels get their topology from one DataFrame, one row each
    N.create_voltage_level_topology(network, DataFrame(id = ["VL1", "VL2"],
                                                       aligned_buses_or_busbar_count = [1, 1],
                                                       section_count = [1, 1],
                                                       switch_kinds = ["", ""]))
    return network, N.get_busbar_sections(network)[:, "id"]
  end

  network, busbars = node_breaker_network()
  @test length(busbars) == 2

  # Injection bays from a DataFrame, one row per bay
  N.create_load_bay(network, DataFrame(id = ["LOAD1", "LOADB"], p0 = [100.0, 50.0],
                                       q0 = [10.0, 5.0],
                                       bus_or_busbar_section_id = [busbars[1], busbars[2]],
                                       position_order = [10, 10],
                                       direction = ["BOTTOM", "BOTTOM"]))
  @test issubset(["LOAD1", "LOADB"], N.get_loads(network)[:, "id"])

  # A branch bay from a DataFrame
  N.create_line_bays(network, DataFrame(id = ["NEW_LINE"], r = [1.0], x = [10.0],
                                        b1 = [0.0], b2 = [0.0], g1 = [0.0], g2 = [0.0],
                                        bus_or_busbar_section_id_1 = [busbars[1]],
                                        bus_or_busbar_section_id_2 = [busbars[2]],
                                        position_order_1 = [20], position_order_2 = [20]))
  @test "NEW_LINE" in N.get_lines(network)[:, "id"]

  # The frames after the first are still column sets, and may be DataFrames themselves
  network2, busbars2 = node_breaker_network()
  N.create_boundary_line_bay(network2,
                             DataFrame(id = ["BL1"], p0 = [10.0], q0 = [3.0],
                                       r = [0.1], x = [1.0], g = [0.0], b = [0.0],
                                       bus_or_busbar_section_id = [busbars2[1]],
                                       position_order = [30], direction = ["BOTTOM"]);
                             column_sets = Any[DataFrame(id = ["BL1"], min_p = [0.0], max_p = [100.0],
                                                         target_p = [50.0], target_q = [10.0],
                                                         target_v = [400.0],
                                                         voltage_regulator_on = [true])])
  generation = N.get_boundary_lines_generation(network2)
  @test count(==("BL1"), generation[:, "id"]) == 1
  @test generation[findfirst(==("BL1"), generation[:, "id"]), "target_p"] == 50.0

  # Alias removal from a DataFrame, two aliases at once
  eurostag = N.create_eurostag_tutorial_example1()
  aliases = DataFrame(id = ["GEN", "GEN2"], alias = ["ALIAS1", "ALIAS2"])
  N.create_elements(eurostag, Powsybl.LibPowsybl.ALIAS,
                    DataFrame(id = aliases[:, "id"], alias = aliases[:, "alias"],
                              alias_type = ["", ""]))
  N.remove_aliases(eurostag, aliases)
  # Re-adding the same aliases only succeeds because the previous ones were removed
  N.create_elements(eurostag, Powsybl.LibPowsybl.ALIAS,
                    DataFrame(id = aliases[:, "id"], alias = aliases[:, "alias"],
                              alias_type = ["", ""]))
  @test "GEN" in N.get_generators(eurostag)[:, "id"]

  # Internal-connection removal reaches the engine from a DataFrame too
  empty_nb = N.create_empty()
  N.create_substations(empty_nb; id = "S1", country = "FR")
  N.create_voltage_levels(empty_nb; id = "VL1", substation_id = "S1",
                          topology_kind = "NODE_BREAKER", nominal_v = 400.0)
  @test_throws Exception N.remove_internal_connections(empty_nb,
                                                        DataFrame(voltage_level_id = ["VL1"],
                                                                  node1 = [0], node2 = [1]))

  # Mixing the two forms is rejected rather than silently dropping one
  network3, busbars3 = node_breaker_network()
  @test_throws ArgumentError N.create_load_bay(network3, DataFrame(id = ["LOAD2"], p0 = [1.0]);
                                                q0 = 1.0)
  @test_throws ArgumentError N.create_coupling_device(network3,
                                                      DataFrame(bus_or_busbar_section_id_1 = [busbars3[1]]);
                                                      bus_or_busbar_section_id_2 = busbars3[2])
end

@testset "Test connectable order positions" begin
  N = Powsybl.Network

  network = N.create_empty()
  N.create_substations(network; id = "S1", country = "FR")
  N.create_voltage_levels(network; id = "VL1", substation_id = "S1",
                          topology_kind = "NODE_BREAKER", nominal_v = 400.0)
  N.create_voltage_level_topology(network; id = "VL1", aligned_buses_or_busbar_count = 1,
                                  section_count = 1, switch_kinds = "")
  busbar = N.get_busbar_sections(network)[:, "id"][1]

  # Created out of order on purpose: the result is sorted by position, not by creation
  N.create_load_bay(network; id = "LOAD1", p0 = 100.0, q0 = 10.0,
                    bus_or_busbar_section_id = busbar, position_order = 30, direction = "BOTTOM")
  N.create_load_bay(network; id = "LOAD2", p0 = 50.0, q0 = 5.0,
                    bus_or_busbar_section_id = busbar, position_order = 10, direction = "TOP")

  positions = N.get_connectables_order_positions(network, "VL1")
  @test names(positions) == ["connectable_id", "order_position", "extension_name"]
  @test positions[:, "connectable_id"] == ["LOAD2", "LOAD1"]
  @test positions[:, "order_position"] == [10, 30]
  @test all(name -> name == rstrip(name), positions[:, "extension_name"])

  # The free intervals are consistent with the positions taken above
  before = N.get_unused_order_positions_before(network, busbar)
  after = N.get_unused_order_positions_after(network, busbar)
  @test before[2] < minimum(positions[:, "order_position"])
  @test after[1] > maximum(positions[:, "order_position"])
end

@testset "Test three-winding transformer replacement" begin
  N = Powsybl.Network

  network = N.create_micro_grid_be()
  transformer_id = N.get_3_windings_transformers(network)[:, "id"][1]
  two_winding_count = nrow(N.get_2_windings_transformers(network))

  # Splitting one three-winding transformer yields three two-winding ones, one per leg
  N.replace_3_windings_transformers_with_3_2_windings_transformers(network, transformer_id)
  @test isempty(N.get_3_windings_transformers(network)[:, "id"])
  split_ids = N.get_2_windings_transformers(network)[:, "id"]
  @test length(split_ids) == two_winding_count + 3
  @test count(id -> startswith(id, transformer_id), split_ids) == 3

  # Merging back restores the topology; the merged transformer is named after its legs
  N.replace_3_2_windings_transformers_with_3_windings_transformers(network)
  merged_ids = N.get_3_windings_transformers(network)[:, "id"]
  @test length(merged_ids) == 1
  @test occursin(transformer_id, merged_ids[1])
  @test nrow(N.get_2_windings_transformers(network)) == two_winding_count

  # No ids given means every transformer of the network
  all_transformers = N.create_micro_grid_be()
  N.replace_3_windings_transformers_with_3_2_windings_transformers(all_transformers)
  @test isempty(N.get_3_windings_transformers(all_transformers)[:, "id"])
end
