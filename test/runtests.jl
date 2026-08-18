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

@testset "Test single line diagram" begin
  network = Powsybl.Network.create_ieee9()
  vl_id = Powsybl.Network.get_voltage_levels(network)[1, "id"]

  diagram = Powsybl.Diagram.get_single_line_diagram(network, vl_id)
  @test occursin("<svg", diagram.svg)
  # The metadata comes back with the diagram rather than only through a file
  @test diagram.metadata !== nothing
  @test occursin(vl_id, diagram.metadata)
  # Printing gives the SVG, and it renders where image/svg+xml is displayed
  @test string(diagram) == diagram.svg
  @test sprint(show, MIME"image/svg+xml"(), diagram) == diagram.svg

  @test !isempty(Powsybl.Diagram.get_single_line_diagram_component_library_names())

  svg_file = tempname() * ".svg"
  Powsybl.Diagram.write_single_line_diagram_svg(network, vl_id, svg_file)
  @test isfile(svg_file)
  @test filesize(svg_file) > 0
end

@testset "Test network area diagram" begin
  network = Powsybl.Network.create_ieee9()
  vl_id = Powsybl.Network.get_voltage_levels(network)[1, "id"]

  diagram = Powsybl.Diagram.get_network_area_diagram(network; voltage_level_ids = [vl_id], depth = 1)
  @test occursin("<svg", diagram.svg)
  @test diagram.metadata !== nothing
  @test string(diagram) == diagram.svg

  displayed = Powsybl.Diagram.get_network_area_diagram_displayed_voltage_levels(network, [vl_id], 1)
  @test displayed isa Vector{String}
  @test vl_id in displayed

  svg_file = tempname() * ".svg"
  Powsybl.Diagram.write_network_area_diagram(network, svg_file)
  @test isfile(svg_file)
  @test filesize(svg_file) > 0
end

@testset "Test diagram parameters" begin
  D = Powsybl.Diagram
  network = Powsybl.Network.create_eurostag_tutorial_example1()
  container = Powsybl.Network.get_voltage_levels(network)[1, "id"]

  # Defaults match the engine's, so asking for them explicitly changes nothing
  plain = D.get_single_line_diagram(network, container)
  @test D.get_single_line_diagram(network, container; parameters = D.SldParameters()).svg == plain.svg

  # The component library the accessor reports can now actually be asked for
  libraries = D.get_single_line_diagram_component_library_names()
  @test length(libraries) > 1
  other = D.get_single_line_diagram(network, container;
                                    parameters = D.SldParameters(component_library = libraries[2]))
  @test other.svg != plain.svg

  # ... and so can the rest of the single line diagram parameters
  named = D.get_single_line_diagram(network, container;
                                    parameters = D.SldParameters(use_name = true, center_name = true))
  @test named.svg != plain.svg

  # The same for the network area diagram, including the edge labels
  nad = D.get_network_area_diagram(network)
  @test D.get_network_area_diagram(network; parameters = D.NadParameters()).svg == nad.svg
  @test D.get_network_area_diagram(network;
                                   parameters = D.NadParameters(id_displayed = true,
                                                                bus_legend = false)).svg != nad.svg
  @test D.get_network_area_diagram(network;
                                   parameters = D.NadParameters(
                                     edge_info_parameters =
                                       D.EdgeInfoParameters(info_side_external = D.CURRENT))).svg != nad.svg

  # The enums take their values from the binding rather than repeating them
  @test Int(D.FORCE_LAYOUT) == Int(Powsybl.LibPowsybl.NAD_LAYOUT_FORCE_LAYOUT)
  @test Int(D.GEOGRAPHICAL) == Int(Powsybl.LibPowsybl.NAD_LAYOUT_GEOGRAPHICAL)
  @test Int(D.ACTIVE_POWER) == Int(Powsybl.LibPowsybl.EDGE_INFO_ACTIVE_POWER)
  @test Int(D.EMPTY) == Int(Powsybl.LibPowsybl.EDGE_INFO_EMPTY)

  # Writers take them too
  svg_file = tempname() * ".svg"
  D.write_single_line_diagram_svg(network, container, svg_file;
                                  parameters = D.SldParameters(component_library = libraries[2]))
  @test filesize(svg_file) > 0
  nad_file = tempname() * ".svg"
  D.write_network_area_diagram(network, nad_file; parameters = D.NadParameters(id_displayed = true))
  @test filesize(nad_file) > 0
end

@testset "Test multi-substation diagram and default NAD profile" begin
  D = Powsybl.Diagram
  network = Powsybl.Network.create_eurostag_tutorial_example1()
  substations = Powsybl.Network.get_substations(network)[:, "id"]
  @test length(substations) >= 2

  # A matrix of substations gives one diagram holding all of them
  matrix = D.get_matrix_multi_substation_single_line_diagram(network, [[substations[1]], [substations[2]]])
  @test occursin("<svg", matrix.svg)
  @test matrix.metadata !== nothing
  # ... which is not the same drawing as either substation on its own
  @test matrix.svg != D.get_single_line_diagram(network, substations[1]).svg
  # The layout is read from the matrix, so a row of two differs from two rows of one
  side_by_side = D.get_matrix_multi_substation_single_line_diagram(network, [[substations[1], substations[2]]])
  @test side_by_side.svg != matrix.svg

  svg_file = tempname() * ".svg"
  D.write_matrix_multi_substation_single_line_diagram_svg(network, [[substations[1], substations[2]]], svg_file)
  @test filesize(svg_file) > 0

  # The default profile fills in the tables the engine can describe by itself
  profile = D.get_default_nad_profile(network)
  @test names(profile.branch_labels)[1] == "id"
  @test size(profile.branch_labels, 1) == size(Powsybl.Network.get_lines(network), 1) +
                                          size(Powsybl.Network.get_2_windings_transformers(network), 1)
  @test size(profile.bus_descriptions, 1) > 0
  @test size(profile.vl_descriptions, 1) == size(Powsybl.Network.get_voltage_levels(network), 1)
  @test profile.three_wt_labels !== nothing
  # The style tables are not something the engine describes, so they stay unset
  @test profile.bus_node_styles === nothing
  @test profile.edge_styles === nothing
  @test profile.three_wt_styles === nothing
end

@testset "Test a single voltage level id needs no vector" begin
  D = Powsybl.Diagram
  network = Powsybl.Network.create_ieee9()
  vl_id = Powsybl.Network.get_voltage_levels(network)[1, "id"]

  # Every call taking a list of voltage levels takes one id on its own too, meaning the same
  @test D.get_network_area_diagram(network; voltage_level_ids = vl_id, depth = 1).svg ==
        D.get_network_area_diagram(network; voltage_level_ids = [vl_id], depth = 1).svg
  @test D.get_network_area_diagram_displayed_voltage_levels(network, vl_id, 1) ==
        D.get_network_area_diagram_displayed_voltage_levels(network, [vl_id], 1)

  single = tempname() * ".svg"
  as_vector = tempname() * ".svg"
  D.write_network_area_diagram(network, single; voltage_level_ids = vl_id, depth = 1)
  D.write_network_area_diagram(network, as_vector; voltage_level_ids = [vl_id], depth = 1)
  @test read(single, String) == read(as_vector, String)

  # A row of the substation matrix takes one id on its own as well
  substation = Powsybl.Network.get_substations(network)[1, "id"]
  @test D.get_matrix_multi_substation_single_line_diagram(network, [substation]).svg ==
        D.get_matrix_multi_substation_single_line_diagram(network, [[substation]]).svg
end
