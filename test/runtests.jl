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

  # Whatever provider parameters the engine reports are carried through rather than
  # dropped. This suite disables configuration reading, under which the provider
  # contributes none, so the invariant is what is asserted rather than a count.
  c_parameters = Powsybl.LibPowsybl.default_loadflow_parameters()
  @test length(parameters.provider_parameters) ==
        length(Powsybl.LibPowsybl.provider_parameters_keys(c_parameters))

  # The provider parameter table is readable, and describes more parameters than a
  # default parameter set carries values for
  provider_table = Powsybl.LoadFlow.get_provider_parameters()
  @test "maxNewtonRaphsonIterations" in provider_table[:, "name"]
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

@testset "Test load flow parameters JSON round-trip" begin
  LF = Powsybl.LoadFlow
  parameters = LF.load_flow_parameters()
  parameters.distributed_slack = false
  parameters.dc_power_factor = 0.95
  parameters.voltage_init_mode = LF.DC_VALUES
  parameters.balance_type = LF.PROPORTIONAL_TO_LOAD
  parameters.countries_to_balance = ["FR", "BE"]
  parameters.hvdc_ac_emulation = false
  parameters.dc = true
  parameters.provider_parameters = Dict("maxNewtonRaphsonIterations" => "20")

  # The JSON carries the values that were set, not merely the names of the settings:
  # every key below is present whatever the parameters say, so the value is the assertion
  json = LF.to_json(parameters)
  @test occursin("\"balanceType\" : \"PROPORTIONAL_TO_LOAD\"", json)
  @test occursin("\"dcPowerFactor\" : 0.95", json)
  @test occursin("\"dc\" : true", json)
  @test occursin("\"hvdcAcEmulation\" : false", json)
  # Provider-specific parameters are serialized into the JSON extensions section
  @test occursin("\"maxNewtonRaphsonIterations\" : 20", json)

  # The common parameters round-trip exactly
  restored = LF.from_json(json)
  @test restored.distributed_slack == false
  @test restored.dc_power_factor == 0.95
  @test restored.voltage_init_mode == LF.DC_VALUES
  @test restored.balance_type == LF.PROPORTIONAL_TO_LOAD
  @test restored.countries_to_balance == ["FR", "BE"]
  @test restored.hvdc_ac_emulation == false
  @test restored.dc == true

  # Parsing fills in the provider's parameters, including the one that was set, which
  # comes back with the value it was given rather than the provider's default
  @test !isempty(restored.provider_parameters)
  @test restored.provider_parameters["maxNewtonRaphsonIterations"] == "20"

  # A default set of parameters is serializable and re-parses to the same defaults
  defaults = LF.load_flow_parameters()
  reparsed = LF.from_json(LF.to_json(defaults))
  @test reparsed.use_reactive_limits == defaults.use_reactive_limits
  @test reparsed.balance_type == defaults.balance_type
  # ... and the "20" above really was the caller's, not what the provider would have said
  @test reparsed.provider_parameters["maxNewtonRaphsonIterations"] != "20"
end