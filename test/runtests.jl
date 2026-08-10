# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

using Powsybl
using Test
using Logging

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

@testset "Test Java logging levels" begin
  # PowSyBl maps these integers onto logback levels: 1 is TRACE and anything it does not
  # know (0) turns logging off, so an inactive logger must map to OFF and not to TRACE.
  @test Powsybl.Log.OFF == 0
  @test Powsybl.Log.TRACE == 1

  @test Powsybl.Log.java_level(TestLogger(min_level = Logging.Debug)) == Powsybl.Log.DEBUG
  @test Powsybl.Log.java_level(TestLogger(min_level = Logging.Info)) == Powsybl.Log.INFO
  @test Powsybl.Log.java_level(TestLogger(min_level = Logging.Warn)) == Powsybl.Log.WARN
  @test Powsybl.Log.java_level(TestLogger(min_level = Logging.Error)) == Powsybl.Log.ERROR
  @test Powsybl.Log.java_level(TestLogger(min_level = Powsybl.Log.TraceLevel)) == Powsybl.Log.TRACE
  @test Powsybl.Log.java_level(NullLogger()) == Powsybl.Log.OFF

  @test Powsybl.Log.julia_level(Powsybl.Log.ERROR) == Logging.Error
  @test Powsybl.Log.julia_level(Powsybl.Log.WARN) == Logging.Warn
  @test Powsybl.Log.julia_level(Powsybl.Log.INFO) == Logging.Info
  # TRACE and DEBUG both surface as Debug, Julia drops anything below it
  @test Powsybl.Log.julia_level(Powsybl.Log.DEBUG) == Logging.Debug
  @test Powsybl.Log.julia_level(Powsybl.Log.TRACE) == Logging.Debug
end

@testset "Test Java logging" begin
  parameters = Powsybl.LoadFlow.load_flow_parameters()

  # PowSyBl messages are emitted through the logger active during the operation
  info_logger = TestLogger(min_level = Logging.Info)
  with_logger(info_logger) do
    Powsybl.LoadFlow.run_ac(Powsybl.Network.create_ieee9(), parameters)
  end
  @test !isempty(info_logger.logs)
  @test any(record -> occursin("OpenLoadFlow", record.message), info_logger.logs)

  # the Java logger name and timestamp are carried along, as pypowsybl does through extra
  @test all(record -> haskey(record.kwargs, :java_logger_name), info_logger.logs)
  @test all(record -> haskey(record.kwargs, :java_timestamp), info_logger.logs)
  @test all(record -> haskey(record.kwargs, :java_level), info_logger.logs)
  @test all(record -> record.group == :powsybl, info_logger.logs)

  # a more verbose logger yields more detail (Debug includes the Java stack traces)
  debug_logger = TestLogger(min_level = Logging.Debug)
  with_logger(debug_logger) do
    Powsybl.LoadFlow.run_ac(Powsybl.Network.create_ieee9(), parameters)
  end
  @test length(debug_logger.logs) >= length(info_logger.logs)

  # a logger that accepts nothing must silence PowSyBl rather than make it verbose
  with_logger(NullLogger()) do
    Powsybl.LoadFlow.run_ac(Powsybl.Network.create_ieee9(), parameters)
  end
  quiet_logger = TestLogger(min_level = Logging.Info)
  with_logger(quiet_logger) do
    Powsybl.Log.flush()
  end
  @test isempty(quiet_logger.logs)

  # set_logger overrides the active logger, and nothing restores the default behaviour
  explicit_logger = TestLogger(min_level = Logging.Info)
  Powsybl.Log.set_logger(explicit_logger)
  try
    with_logger(NullLogger()) do
      Powsybl.LoadFlow.run_ac(Powsybl.Network.create_ieee9(), parameters)
    end
    @test !isempty(explicit_logger.logs)
    @test Powsybl.Log.get_logger() === explicit_logger
  finally
    Powsybl.Log.set_logger(nothing)
  end
end
