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

@testset "Test the shared contingency context type" begin
  C = Powsybl.Contingency

  # The four states a computation can be asked to report on
  @test Set(instances(C.ContingencyContextType)) ==
        Set([C.ALL, C.NONE, C.SPECIFIC, C.ONLY_CONTINGENCIES])

  # Values come from the binding rather than being repeated here
  @test Int(C.ALL) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_ALL)
  @test Int(C.NONE) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_NONE)
  @test Int(C.SPECIFIC) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC)
  @test Int(C.ONLY_CONTINGENCIES) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_ONLY_CONTINGENCIES)

  # ... and convert back to what the engine expects
  @test C.raw(C.SPECIFIC) == Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC
end

@testset "Test sensitivity enum values come from the binding" begin
  # The enum members must track the C enums rather than repeat their values, so that a
  # renumbering upstream cannot silently change which factor is computed.
  @test Int(Powsybl.SensitivityAnalysis.BRANCH_ACTIVE_POWER_1) == Int(Powsybl.LibPowsybl.BRANCH_ACTIVE_POWER_1)
  @test Int(Powsybl.SensitivityAnalysis.BUS_VOLTAGE) == Int(Powsybl.LibPowsybl.BUS_VOLTAGE)
  @test Int(Powsybl.SensitivityAnalysis.AUTO_DETECT) == Int(Powsybl.LibPowsybl.AUTO_DETECT)
  @test Int(Powsybl.SensitivityAnalysis.TRANSFORMER_PHASE_3) == Int(Powsybl.LibPowsybl.TRANSFORMER_PHASE_3)
  @test Int(Powsybl.SensitivityAnalysis.ALL) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_ALL)
  @test Int(Powsybl.SensitivityAnalysis.SPECIFIC) == Int(Powsybl.LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC)

  # Every member of each enum is distinct and contiguous from zero
  @test [Int(x) for x in instances(Powsybl.SensitivityAnalysis.SensitivityFunctionType)] == collect(0:10)
  @test [Int(x) for x in instances(Powsybl.SensitivityAnalysis.SensitivityVariableType)] == collect(0:8)
  @test [Int(x) for x in instances(Powsybl.SensitivityAnalysis.ContingencyContextType)] == collect(0:3)
end

@testset "Test sensitivity analysis providers" begin
  @test !isempty(Powsybl.SensitivityAnalysis.get_provider_names())

  default_provider = Powsybl.SensitivityAnalysis.get_default_provider()
  @test default_provider isa String
  @test default_provider in Powsybl.SensitivityAnalysis.get_provider_names()

  # The parameter names of a provider are the keys its provider parameters accept
  @test Powsybl.SensitivityAnalysis.get_provider_parameters_names() isa Vector{String}

  Powsybl.SensitivityAnalysis.set_default_provider(default_provider)
  @test Powsybl.SensitivityAnalysis.get_default_provider() == default_provider
end

@testset "Test sensitivity analysis" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  branches = ["L7-8-0", "L9-8-0", "L7-5-0"]

  analysis = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(analysis, branches, generators)

  result = Powsybl.SensitivityAnalysis.run(analysis, network)

  # Rows are the variables, columns the monitored functions, both named
  sensitivities = Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result)
  @test sensitivities isa DataFrame
  @test names(sensitivities) == vcat("id", branches)
  @test sensitivities[:, "id"] == generators
  @test size(sensitivities) == (length(generators), length(branches) + 1)

  references = Powsybl.SensitivityAnalysis.get_reference_matrix(result)
  @test names(references) == vcat("id", branches)
  @test references[:, "id"] == ["reference_values"]

  # The unlabelled values stay available
  @test Powsybl.SensitivityAnalysis.get_sensitivity_values(result) isa Matrix{Float64}
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_values(result)) ==
        (length(generators), length(branches))
end

@testset "Test AC and DC contexts" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]

  # The context decides the mode, so run takes no ac/dc of its own
  dc = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(dc, ["L7-8-0"], generators)
  @test dc isa Powsybl.SensitivityAnalysis.DcSensitivityAnalysisContext
  @test nrow(Powsybl.SensitivityAnalysis.get_reference_matrix(
               Powsybl.SensitivityAnalysis.run(dc, network))) == 1

  ac = Powsybl.SensitivityAnalysis.create_ac_analysis()
  @test ac isa Powsybl.SensitivityAnalysis.AcSensitivityAnalysisContext

  # Bus voltage sensitivities only exist in AC, so the helper is only on an AC context
  buses = Powsybl.Network.get_buses(network)[:, "id"]
  Powsybl.SensitivityAnalysis.add_bus_voltage_factor_matrix(ac, [buses[1]], [generators[1]])
  voltages = Powsybl.SensitivityAnalysis.get_sensitivity_matrix(
               Powsybl.SensitivityAnalysis.run(ac, network))
  @test names(voltages) == ["id", buses[1]]
  @test voltages[:, "id"] == [generators[1]]

  @test_throws MethodError Powsybl.SensitivityAnalysis.add_bus_voltage_factor_matrix(dc, [buses[1]], [generators[1]])
end

@testset "Test power transfer variables" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  branches = ["L7-8-0", "L9-8-0"]
  first_gen, second_gen = generators[1], generators[2]

  # Registered separately, to read the two sensitivities the transfer is built from
  separate = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(separate, branches, [first_gen, second_gen])
  separate_values = Powsybl.SensitivityAnalysis.get_sensitivity_matrix(
                      Powsybl.SensitivityAnalysis.run(separate, network))

  # The same pair registered as a transfer collapses to one row, named after both
  transfer = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_factor_matrix(transfer, branches, [(first_gen, second_gen)])
  transferred = Powsybl.SensitivityAnalysis.get_sensitivity_matrix(
                  Powsybl.SensitivityAnalysis.run(transfer, network))

  @test nrow(transferred) == 1
  @test transferred[1, "id"] == first_gen * " -> " * second_gen

  # ... and holds the difference of the two separate sensitivities
  for branch in branches
    @test transferred[1, branch] ≈ separate_values[1, branch] - separate_values[2, branch] atol = 1e-9
  end

  # The unfolded values still show both rows
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_values(
              Powsybl.SensitivityAnalysis.run(transfer, network)), 1) == 2

  # A malformed variable is rejected
  bad = Powsybl.SensitivityAnalysis.create_dc_analysis()
  @test_throws ArgumentError Powsybl.SensitivityAnalysis.add_factor_matrix(bad, branches, [(first_gen, second_gen, "x")])
  @test_throws ArgumentError Powsybl.SensitivityAnalysis.add_factor_matrix(bad, branches, [42])
end

@testset "Test branch flow factor matrix helpers" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  branches = ["L7-8-0", "L9-8-0"]

  analysis = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_single_element_contingency(analysis, "L7-5-0")

  # Evaluated on the base case and on every contingency
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(analysis, branches, generators; matrix_id = "all")
  # ... on the base case only
  Powsybl.SensitivityAnalysis.add_precontingency_branch_flow_factor_matrix(analysis, branches, generators; matrix_id = "pre")
  # ... on the listed contingencies only
  Powsybl.SensitivityAnalysis.add_postcontingency_branch_flow_factor_matrix(analysis, branches, generators,
                                                                            ["L7-5-0"]; matrix_id = "post")

  result = Powsybl.SensitivityAnalysis.run(analysis, network)
  expected = (length(generators), length(branches) + 1)

  # The "all" matrix exists in both states, "pre" only in the base case and "post" only
  # in the contingency, which is what the contingency context of each helper selects
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result, "all", "")) == expected
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result, "all", "L7-5-0")) == expected
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result, "pre", "")) == expected
  @test size(Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result, "post", "L7-5-0")) == expected
end

@testset "Test sensitivity analysis contingencies" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  analysis = Powsybl.SensitivityAnalysis.create_dc_analysis()

  # One N-1 contingency per element, the element id naming the contingency
  Powsybl.SensitivityAnalysis.add_single_element_contingencies(analysis, ["L7-8-0"])
  # ... or an id derived from the element
  Powsybl.SensitivityAnalysis.add_single_element_contingencies(analysis, ["L7-5-0"];
                                                               contingency_id_provider = id -> "ctg_" * id)
  # ... or read from a JSON contingency list
  Powsybl.SensitivityAnalysis.add_contingencies_from_json_file(analysis, "contingencies.json")

  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(analysis, ["L9-6-0"], generators)
  result = Powsybl.SensitivityAnalysis.run(analysis, network)

  # Each contingency is retrievable by the id it was registered under
  for contingency_id in ["", "L7-8-0", "ctg_L7-5-0", "fromJson"]
    matrix = Powsybl.SensitivityAnalysis.get_sensitivity_matrix(result, "default", contingency_id)
    @test size(matrix) == (length(generators), 2)   # the id column plus the single branch
  end
end

@testset "Test sensitivity analysis parameters" begin
  parameters = Powsybl.SensitivityAnalysis.Parameters()
  @test parameters.load_flow_parameters isa Powsybl.LoadFlow.LoadFlowParameters
  @test parameters.flow_flow_sensitivity_value_threshold isa Float64
  @test parameters.provider_parameters == Dict{String, String}()

  # Thresholds are carried through to the run
  parameters.flow_flow_sensitivity_value_threshold = 0.01
  parameters.angle_flow_sensitivity_value_threshold = 0.01

  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  analysis = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(analysis, ["L7-8-0"], generators)

  result = Powsybl.SensitivityAnalysis.run(analysis, network, parameters)
  @test nrow(Powsybl.SensitivityAnalysis.get_reference_matrix(result)) == 1

  # Keyword overrides start from the provider defaults
  overridden = Powsybl.SensitivityAnalysis.Parameters(flow_flow_sensitivity_value_threshold = 0.5)
  @test overridden.flow_flow_sensitivity_value_threshold == 0.5
  @test overridden.voltage_voltage_sensitivity_value_threshold ==
        Powsybl.SensitivityAnalysis.Parameters().voltage_voltage_sensitivity_value_threshold

  # Load flow parameters alone stay accepted, the rest keeping their defaults
  result = Powsybl.SensitivityAnalysis.run(analysis, network, Powsybl.LoadFlow.load_flow_parameters())
  @test nrow(Powsybl.SensitivityAnalysis.get_reference_matrix(result)) == 1
end

@testset "Test sensitivity analysis report node" begin
  network = Powsybl.Network.create_ieee9()
  generators = Powsybl.Network.get_generators(network)[:, "id"]
  analysis = Powsybl.SensitivityAnalysis.create_dc_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(analysis, ["L7-8-0"], generators)

  # A report node collects the functional logs of the run, in DC and in AC
  dc_report = Powsybl.Report.ReportNode()
  dc_result = Powsybl.SensitivityAnalysis.run(analysis, network; report_node = dc_report)
  @test nrow(Powsybl.SensitivityAnalysis.get_reference_matrix(dc_result)) == 1
  @test !isempty(string(dc_report))

  ac_analysis = Powsybl.SensitivityAnalysis.create_ac_analysis()
  Powsybl.SensitivityAnalysis.add_branch_flow_factor_matrix(ac_analysis, ["L7-8-0"], generators)
  ac_report = Powsybl.Report.ReportNode()
  ac_result = Powsybl.SensitivityAnalysis.run(ac_analysis, network; report_node = ac_report)
  @test nrow(Powsybl.SensitivityAnalysis.get_reference_matrix(ac_result)) == 1
  @test !isempty(string(ac_report))
end
