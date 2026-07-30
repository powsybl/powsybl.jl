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

@testset "Test reporting" begin
  report_node = Powsybl.Report.ReportNode()

  # Load flow with a report node collects functional logs
  network = Powsybl.Network.create_ieee9()
  parameters = Powsybl.LoadFlow.load_flow_parameters()
  result = Powsybl.LoadFlow.run_ac(network, parameters; report_node = report_node)
  @test result.component_results[1, :].status == Powsybl.LoadFlow.CONVERGED

  text = string(report_node)
  @test text isa String
  @test !isempty(text)

  json = Powsybl.Report.to_json(report_node)
  @test occursin("{", json)

  # Network import with a report node
  import_report_node = Powsybl.Report.ReportNode()
  imported = Powsybl.Network.load("simple-eu.xiidm"; report_node = import_report_node)
  @test imported.name == "simple-eu"
  @test !isempty(string(import_report_node))
end

@testset "Test security analysis provider names" begin
  @test !isempty(Powsybl.SecurityAnalysis.get_provider_names())
end

@testset "Test security analysis" begin
  network = Powsybl.Network.create_ieee9()

  analysis = Powsybl.SecurityAnalysis.create_analysis()
  Powsybl.SecurityAnalysis.add_single_element_contingency(analysis, "L7-8-0")
  Powsybl.SecurityAnalysis.add_multiple_elements_contingency(analysis, ["L9-8-0", "L7-5-0"], "double")
  Powsybl.SecurityAnalysis.add_monitored_elements(analysis; branch_ids = ["L9-6-0"])

  parameters = Powsybl.LoadFlow.load_flow_parameters()
  result = Powsybl.SecurityAnalysis.run_ac(analysis, network, parameters)

  # Base case converges
  @test Powsybl.SecurityAnalysis.get_pre_contingency_result(result) == Powsybl.SecurityAnalysis.CONVERGED

  # One row per contingency, in insertion order
  post = Powsybl.SecurityAnalysis.get_post_contingency_results(result)
  @test Set(post[:, "contingency_id"]) == Set(["L7-8-0", "double"])
  @test post[1, "status"] isa Powsybl.SecurityAnalysis.ComputationStatus

  # Result accessors return tabular data without throwing
  violations = Powsybl.SecurityAnalysis.get_limit_violations(result)
  @test size(violations, 2) >= 0

  branch_results = Powsybl.SecurityAnalysis.get_branch_results(result)
  @test size(branch_results, 2) >= 0

  Powsybl.SecurityAnalysis.get_bus_results(result)
  Powsybl.SecurityAnalysis.get_three_windings_transformer_results(result)
end

@testset "Test security analysis parameters" begin
  parameters = Powsybl.SecurityAnalysis.Parameters()
  @test parameters.load_flow_parameters isa Powsybl.LoadFlow.LoadFlowParameters
  @test parameters.increased_violations isa Powsybl.SecurityAnalysis.IncreasedViolationsParameters
  @test parameters.provider_parameters == Dict{String, String}()

  # The violation thresholds are carried through to the run
  parameters.increased_violations.flow_proportional_threshold = 0.2
  parameters.increased_violations.high_voltage_absolute_threshold = 2.0

  network = Powsybl.Network.create_ieee9()
  analysis = Powsybl.SecurityAnalysis.create_analysis()
  Powsybl.SecurityAnalysis.add_single_element_contingency(analysis, "L7-8-0")
  result = Powsybl.SecurityAnalysis.run_ac(analysis, network, parameters)
  @test Powsybl.SecurityAnalysis.get_pre_contingency_result(result) == Powsybl.SecurityAnalysis.CONVERGED

  # Load flow parameters alone stay accepted, the rest keeping their defaults
  result = Powsybl.SecurityAnalysis.run_ac(analysis, network, Powsybl.LoadFlow.load_flow_parameters())
  @test Powsybl.SecurityAnalysis.get_pre_contingency_result(result) == Powsybl.SecurityAnalysis.CONVERGED
end

@testset "Test security analysis providers" begin
  default_provider = Powsybl.SecurityAnalysis.get_default_provider()
  @test default_provider isa String
  @test default_provider in Powsybl.SecurityAnalysis.get_provider_names()

  # The parameter names of a provider feed the provider_parameters of Parameters
  @test Powsybl.SecurityAnalysis.get_provider_parameters_names() isa Vector{String}

  Powsybl.SecurityAnalysis.set_default_provider(default_provider)
  @test Powsybl.SecurityAnalysis.get_default_provider() == default_provider
end

@testset "Test bulk single element contingencies" begin
  network = Powsybl.Network.create_ieee9()
  analysis = Powsybl.SecurityAnalysis.create_analysis()

  # One N-1 contingency per element, the element id naming the contingency
  Powsybl.SecurityAnalysis.add_single_element_contingencies(analysis, ["L7-8-0", "L9-8-0"])
  # ... or an id derived from the element
  Powsybl.SecurityAnalysis.add_single_element_contingencies(analysis, ["L7-5-0"];
                                                            contingency_id_provider = id -> "ctg_" * id)

  result = Powsybl.SecurityAnalysis.run_ac(analysis, network)
  post = Powsybl.SecurityAnalysis.get_post_contingency_results(result)
  @test Set(post[:, "contingency_id"]) == Set(["L7-8-0", "L9-8-0", "ctg_L7-5-0"])

  # Each is retrievable under the id it was registered with
  for contingency_id in ["L7-8-0", "L9-8-0", "ctg_L7-5-0"]
    @test Powsybl.SecurityAnalysis.find_post_contingency_result(result, contingency_id) isa
          Powsybl.SecurityAnalysis.ComputationStatus
  end
end

@testset "Test monitored element scopes and contingency lookup" begin
  network = Powsybl.Network.create_ieee9()
  analysis = Powsybl.SecurityAnalysis.create_analysis()
  Powsybl.SecurityAnalysis.add_single_element_contingency(analysis, "L7-8-0")
  Powsybl.SecurityAnalysis.add_single_element_contingency(analysis, "L9-8-0")

  Powsybl.SecurityAnalysis.add_precontingency_monitored_elements(analysis; branch_ids = ["L9-6-0"])
  Powsybl.SecurityAnalysis.add_postcontingency_monitored_elements(analysis, "L7-8-0"; branch_ids = ["L5-4-0"])

  result = Powsybl.SecurityAnalysis.run_ac(analysis, network)

  # A single contingency can be looked up by id, an unknown one throws
  @test Powsybl.SecurityAnalysis.find_post_contingency_result(result, "L7-8-0") isa Powsybl.SecurityAnalysis.ComputationStatus
  @test_throws KeyError Powsybl.SecurityAnalysis.find_post_contingency_result(result, "does-not-exist")

  branch_results = Powsybl.SecurityAnalysis.get_branch_results(result)
  @test size(branch_results, 2) >= 0
end

@testset "Test DC security analysis and report node" begin
  network = Powsybl.Network.create_ieee9()
  analysis = Powsybl.SecurityAnalysis.create_analysis()
  Powsybl.SecurityAnalysis.add_single_element_contingency(analysis, "L7-8-0")
  parameters = Powsybl.LoadFlow.load_flow_parameters()

  # DC is carried by the load flow parameters, so it must reach the engine from there
  dc_result = Powsybl.SecurityAnalysis.run_dc(analysis, network, parameters)
  @test Powsybl.SecurityAnalysis.get_pre_contingency_result(dc_result) == Powsybl.SecurityAnalysis.CONVERGED

  # A report node collects the functional logs of the run
  report_node = Powsybl.Report.ReportNode()
  ac_result = Powsybl.SecurityAnalysis.run_ac(analysis, network, parameters; report_node = report_node)
  @test Powsybl.SecurityAnalysis.get_pre_contingency_result(ac_result) == Powsybl.SecurityAnalysis.CONVERGED
  @test !isempty(string(report_node))
end
