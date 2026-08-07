# Copyright (c) 2026, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module SecurityAnalysis
  using ..LibPowsybl
  using ..Network
  using ..LoadFlow
  using DataFrames
  using CxxWrap

  """
  Computation status of a pre- or post-contingency state of a security analysis.
  """
  @enum ComputationStatus begin
    CONVERGED = LibPowsybl.POST_CONTINGENCY_CONVERGED
    MAX_ITERATION_REACHED = LibPowsybl.POST_CONTINGENCY_MAX_ITERATION_REACHED
    SOLVER_FAILED = LibPowsybl.POST_CONTINGENCY_SOLVER_FAILED
    FAILED = LibPowsybl.POST_CONTINGENCY_FAILED
    NO_IMPACT = LibPowsybl.POST_CONTINGENCY_NO_IMPACT
  end

  """
  Defines for which contingencies a monitored element is observed:
  `ALL` (base case and every contingency), `NONE`, `SPECIFIC` (the listed
  contingencies), or `ONLY_CONTINGENCIES`.
  """
  @enum ContingencyContextType begin
    ALL = LibPowsybl.CONTINGENCY_CONTEXT_ALL
    NONE = LibPowsybl.CONTINGENCY_CONTEXT_NONE
    SPECIFIC = LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC
    ONLY_CONTINGENCIES = LibPowsybl.CONTINGENCY_CONTEXT_ONLY_CONTINGENCIES
  end

  """
  Thresholds deciding when a limit violation of a contingency state counts as increased
  with respect to the base case.
  """
  mutable struct IncreasedViolationsParameters
    flow_proportional_threshold::Float64
    low_voltage_proportional_threshold::Float64
    low_voltage_absolute_threshold::Float64
    high_voltage_proportional_threshold::Float64
    high_voltage_absolute_threshold::Float64
  end

  """
  Parameters of a security analysis run: the load flow parameters used for the base case
  and every contingency, the thresholds for increased violations, and the parameters
  specific to the security analysis provider.

  Every field is first read from the configuration, then overridden by the keywords given
  to [`Parameters`](@ref).
  """
  mutable struct Parameters
    load_flow_parameters::LoadFlow.LoadFlowParameters
    increased_violations::IncreasedViolationsParameters
    provider_parameters::Dict{String, String}
  end

  """
      Parameters(; load_flow_parameters, increased_violations, provider_parameters) -> Parameters

  Build the security analysis parameters, starting from the provider defaults.
  """
  function Parameters(; load_flow_parameters::Union{Nothing, LoadFlow.LoadFlowParameters} = nothing,
                        increased_violations::Union{Nothing, IncreasedViolationsParameters} = nothing,
                        provider_parameters::Union{Nothing, Dict{String, String}} = nothing)
    defaults = _default_parameters()
    return Parameters(load_flow_parameters === nothing ? defaults.load_flow_parameters : load_flow_parameters,
                      increased_violations === nothing ? defaults.increased_violations : increased_violations,
                      provider_parameters === nothing ? defaults.provider_parameters : provider_parameters)
  end

  function _default_parameters()
    c_parameters = LibPowsybl.default_security_analysis_parameters()
    return Parameters(LoadFlow.c_parameters_to_julia_struct(LibPowsybl.loadflow_parameters(c_parameters)),
                      IncreasedViolationsParameters(LibPowsybl.flow_proportional_threshold(c_parameters),
                                                    LibPowsybl.low_voltage_proportional_threshold(c_parameters),
                                                    LibPowsybl.low_voltage_absolute_threshold(c_parameters),
                                                    LibPowsybl.high_voltage_proportional_threshold(c_parameters),
                                                    LibPowsybl.high_voltage_absolute_threshold(c_parameters)),
                      Dict{String, String}())
  end

  function _to_c_parameters(parameters::Parameters)
    c_parameters = LibPowsybl.default_security_analysis_parameters()
    LibPowsybl.loadflow_parameters(c_parameters, LoadFlow.load_flow_parameters_to_c_struct(parameters.load_flow_parameters))
    LibPowsybl.flow_proportional_threshold(c_parameters, parameters.increased_violations.flow_proportional_threshold)
    LibPowsybl.low_voltage_proportional_threshold(c_parameters, parameters.increased_violations.low_voltage_proportional_threshold)
    LibPowsybl.low_voltage_absolute_threshold(c_parameters, parameters.increased_violations.low_voltage_absolute_threshold)
    LibPowsybl.high_voltage_proportional_threshold(c_parameters, parameters.increased_violations.high_voltage_proportional_threshold)
    LibPowsybl.high_voltage_absolute_threshold(c_parameters, parameters.increased_violations.high_voltage_absolute_threshold)
    LibPowsybl.provider_parameters_keys(c_parameters, StdVector{StdString}(collect(keys(parameters.provider_parameters))))
    LibPowsybl.provider_parameters_values(c_parameters, StdVector{StdString}(collect(values(parameters.provider_parameters))))
    return c_parameters
  end

  """
  Side of a branch or three windings transformer a remedial action or a limit
  violation refers to. `SIDE_NONE` means no particular side.
  """
  @enum Side begin
    SIDE_NONE = LibPowsybl.THREE_SIDE_UNDEFINED
    SIDE_ONE = LibPowsybl.THREE_SIDE_ONE
    SIDE_TWO = LibPowsybl.THREE_SIDE_TWO
    SIDE_THREE = LibPowsybl.THREE_SIDE_THREE
  end

  """
  Condition under which the remedial actions of an operator strategy are applied
  after a contingency.
  """
  @enum ConditionType begin
    TRUE_CONDITION = LibPowsybl.CONDITION_TRUE
    ALL_VIOLATION_CONDITION = LibPowsybl.CONDITION_ALL_VIOLATION
    ANY_VIOLATION_CONDITION = LibPowsybl.CONDITION_ANY_VIOLATION
    AT_LEAST_ONE_VIOLATION_CONDITION = LibPowsybl.CONDITION_AT_LEAST_ONE_VIOLATION
  end

  """
  Type of limit violation used to filter an operator strategy condition.
  """
  @enum ViolationType begin
    ACTIVE_POWER = LibPowsybl.VIOLATION_ACTIVE_POWER
    APPARENT_POWER = LibPowsybl.VIOLATION_APPARENT_POWER
    CURRENT = LibPowsybl.VIOLATION_CURRENT
    LOW_VOLTAGE = LibPowsybl.VIOLATION_LOW_VOLTAGE
    HIGH_VOLTAGE = LibPowsybl.VIOLATION_HIGH_VOLTAGE
    LOW_SHORT_CIRCUIT_CURRENT = LibPowsybl.VIOLATION_LOW_SHORT_CIRCUIT_CURRENT
    HIGH_SHORT_CIRCUIT_CURRENT = LibPowsybl.VIOLATION_HIGH_SHORT_CIRCUIT_CURRENT
    OTHER = LibPowsybl.VIOLATION_OTHER
  end

  """
  A security analysis context: it collects the contingencies and monitored elements
  to analyse before being run against a network.
  """
  mutable struct SecurityAnalysisContext
    handle::LibPowsybl.JavaHandle
  end

  """
  The result of a security analysis run. Query it through `get_limit_violations`,
  `get_pre_contingency_result`, `get_post_contingency_results` and the monitored
  element result accessors.
  """
  mutable struct Result
    handle::LibPowsybl.JavaHandle
  end

  """
      create_analysis() -> SecurityAnalysisContext

  Create an empty security analysis context.
  """
  function create_analysis()
    return SecurityAnalysisContext(LibPowsybl.create_security_analysis())
  end

  """
      add_single_element_contingency(analysis, element_id[, contingency_id])

  Add a contingency tripping a single element. When omitted, the contingency id
  defaults to the element id.
  """
  function add_single_element_contingency(analysis::SecurityAnalysisContext, element_id::String, contingency_id::String = element_id)
    LibPowsybl.add_contingency(analysis.handle, contingency_id, StdVector{StdString}([element_id]))
    return nothing
  end

  """
      add_multiple_elements_contingency(analysis, elements_ids, contingency_id)

  Add a contingency tripping several elements simultaneously (an N-k contingency).
  """
  function add_multiple_elements_contingency(analysis::SecurityAnalysisContext, elements_ids::Vector{String}, contingency_id::String)
    LibPowsybl.add_contingency(analysis.handle, contingency_id, StdVector{StdString}(elements_ids))
    return nothing
  end

  """
      add_single_element_contingencies(analysis, elements_ids; contingency_id_provider = nothing)

  Add one single-element contingency per element id. `contingency_id_provider` maps an
  element id to the id its contingency is registered under; when omitted the element id
  is used.
  """
  function add_single_element_contingencies(analysis::SecurityAnalysisContext, elements_ids::Vector{String};
                                            contingency_id_provider = nothing)
    for element_id in elements_ids
      contingency_id = contingency_id_provider === nothing ? element_id : contingency_id_provider(element_id)
      add_single_element_contingency(analysis, element_id, contingency_id)
    end
    return nothing
  end

  """
      add_monitored_elements(analysis; contingency_context_type = ALL, branch_ids,
                             voltage_level_ids, three_windings_transformer_ids,
                             contingency_ids)

  Register elements whose detailed results (flows, voltages) should be collected during
  the analysis. `contingency_context_type` selects the states in which they are
  monitored; `contingency_ids` restricts a `SPECIFIC` context to the given contingencies.
  """
  function add_monitored_elements(analysis::SecurityAnalysisContext;
                                  contingency_context_type::ContingencyContextType = ALL,
                                  branch_ids::Vector{String} = String[],
                                  voltage_level_ids::Vector{String} = String[],
                                  three_windings_transformer_ids::Vector{String} = String[],
                                  contingency_ids::Vector{String} = String[])
    LibPowsybl.add_monitored_elements(analysis.handle,
                                      LibPowsybl.ContingencyContextType(contingency_context_type),
                                      StdVector{StdString}(branch_ids),
                                      StdVector{StdString}(voltage_level_ids),
                                      StdVector{StdString}(three_windings_transformer_ids),
                                      StdVector{StdString}(contingency_ids))
    return nothing
  end

  """
      add_precontingency_monitored_elements(analysis; branch_ids, voltage_level_ids,
                                            three_windings_transformer_ids)

  Register elements monitored on the base case only.
  """
  function add_precontingency_monitored_elements(analysis::SecurityAnalysisContext;
                                                 branch_ids::Vector{String} = String[],
                                                 voltage_level_ids::Vector{String} = String[],
                                                 three_windings_transformer_ids::Vector{String} = String[])
    return add_monitored_elements(analysis; contingency_context_type = NONE,
                                  branch_ids = branch_ids,
                                  voltage_level_ids = voltage_level_ids,
                                  three_windings_transformer_ids = three_windings_transformer_ids)
  end

  """
      add_postcontingency_monitored_elements(analysis, contingency_ids; branch_ids,
                                             voltage_level_ids, three_windings_transformer_ids)

  Register elements monitored for the given contingencies only.
  """
  function add_postcontingency_monitored_elements(analysis::SecurityAnalysisContext, contingency_ids::Vector{String};
                                                  branch_ids::Vector{String} = String[],
                                                  voltage_level_ids::Vector{String} = String[],
                                                  three_windings_transformer_ids::Vector{String} = String[])
    return add_monitored_elements(analysis; contingency_context_type = SPECIFIC,
                                  contingency_ids = contingency_ids,
                                  branch_ids = branch_ids,
                                  voltage_level_ids = voltage_level_ids,
                                  three_windings_transformer_ids = three_windings_transformer_ids)
  end

  function add_postcontingency_monitored_elements(analysis::SecurityAnalysisContext, contingency_id::String; kwargs...)
    return add_postcontingency_monitored_elements(analysis, [contingency_id]; kwargs...)
  end

  # Load flow parameters alone are accepted too, the rest of the security analysis
  # parameters then keeping their default values.
  _as_parameters(parameters::Parameters) = parameters
  _as_parameters(parameters::LoadFlow.LoadFlowParameters) = Parameters(load_flow_parameters = parameters)

  # Remedial actions

  """
      add_load_active_power_action(analysis, action_id, load_id, is_relative, active_power)

  Add a remedial action changing the active power set point of a load. When
  `is_relative` is `true` the value is added to the current set point, otherwise it
  replaces it.
  """
  function add_load_active_power_action(analysis::SecurityAnalysisContext, action_id::String, load_id::String,
                                        is_relative::Bool, active_power::Float64)
    LibPowsybl.add_load_active_power_action(analysis.handle, action_id, load_id, is_relative, active_power)
    return nothing
  end

  """
      add_load_reactive_power_action(analysis, action_id, load_id, is_relative, reactive_power)

  Add a remedial action changing the reactive power set point of a load.
  See [`add_load_active_power_action`](@ref).
  """
  function add_load_reactive_power_action(analysis::SecurityAnalysisContext, action_id::String, load_id::String,
                                          is_relative::Bool, reactive_power::Float64)
    LibPowsybl.add_load_reactive_power_action(analysis.handle, action_id, load_id, is_relative, reactive_power)
    return nothing
  end

  """
      add_generator_active_power_action(analysis, action_id, generator_id, is_relative, active_power)

  Add a remedial action changing the active power target of a generator.
  See [`add_load_active_power_action`](@ref).
  """
  function add_generator_active_power_action(analysis::SecurityAnalysisContext, action_id::String, generator_id::String,
                                             is_relative::Bool, active_power::Float64)
    LibPowsybl.add_generator_active_power_action(analysis.handle, action_id, generator_id, is_relative, active_power)
    return nothing
  end

  """
      add_switch_action(analysis, action_id, switch_id, open)

  Add a remedial action opening (`open = true`) or closing (`open = false`) a switch.
  """
  function add_switch_action(analysis::SecurityAnalysisContext, action_id::String, switch_id::String, open::Bool)
    LibPowsybl.add_switch_action(analysis.handle, action_id, switch_id, open)
    return nothing
  end

  """
      add_phase_tap_changer_position_action(analysis, action_id, transformer_id, is_relative, tap_position;
                                            side = SIDE_NONE)

  Add a remedial action setting the tap position of a transformer's phase tap changer.
  When `is_relative` is `true` the position is added to the current one, otherwise it
  replaces it. `side` selects the leg of a three windings transformer (`SIDE_NONE` for a
  two windings transformer).
  """
  function add_phase_tap_changer_position_action(analysis::SecurityAnalysisContext, action_id::String,
                                                 transformer_id::String, is_relative::Bool, tap_position::Integer;
                                                 side::Side = SIDE_NONE)
    LibPowsybl.add_phase_tap_changer_position_action(analysis.handle, action_id, transformer_id, is_relative,
                                                     Cint(tap_position), LibPowsybl.ThreeSide(side))
    return nothing
  end

  """
      add_ratio_tap_changer_position_action(analysis, action_id, transformer_id, is_relative, tap_position;
                                            side = SIDE_NONE)

  Add a remedial action setting the tap position of a transformer's ratio tap changer.
  See [`add_phase_tap_changer_position_action`](@ref).
  """
  function add_ratio_tap_changer_position_action(analysis::SecurityAnalysisContext, action_id::String,
                                                 transformer_id::String, is_relative::Bool, tap_position::Integer;
                                                 side::Side = SIDE_NONE)
    LibPowsybl.add_ratio_tap_changer_position_action(analysis.handle, action_id, transformer_id, is_relative,
                                                     Cint(tap_position), LibPowsybl.ThreeSide(side))
    return nothing
  end

  """
      add_shunt_compensator_position_action(analysis, action_id, shunt_id, section)

  Add a remedial action setting the number of connected sections of a shunt compensator.
  """
  function add_shunt_compensator_position_action(analysis::SecurityAnalysisContext, action_id::String,
                                                 shunt_id::String, section::Integer)
    LibPowsybl.add_shunt_compensator_position_action(analysis.handle, action_id, shunt_id, Cint(section))
    return nothing
  end

  """
      add_terminals_connection_action(analysis, action_id, element_id; side = SIDE_NONE, opening = true)

  Add a remedial action opening (`opening = true`) or closing (`opening = false`) the
  terminals of an element. `side` restricts the action to one side of the element.
  """
  function add_terminals_connection_action(analysis::SecurityAnalysisContext, action_id::String, element_id::String;
                                           side::Side = SIDE_NONE, opening::Bool = true)
    LibPowsybl.add_terminals_connection_action(analysis.handle, action_id, element_id, LibPowsybl.ThreeSide(side), opening)
    return nothing
  end

  # Operator strategies

  """
      add_operator_strategy(analysis, operator_strategy_id, contingency_id, action_ids;
                            condition_type = TRUE_CONDITION, violation_subject_ids = String[],
                            violation_types = ViolationType[])

  Register an operator strategy: after `contingency_id` occurs, apply the remedial
  actions listed in `action_ids` (previously added with the `add_*_action` helpers)
  when `condition_type` is met. For the violation-based conditions,
  `violation_subject_ids` and `violation_types` restrict which violations trigger it.
  """
  function add_operator_strategy(analysis::SecurityAnalysisContext, operator_strategy_id::String,
                                 contingency_id::String, action_ids::Vector{String};
                                 condition_type::ConditionType = TRUE_CONDITION,
                                 violation_subject_ids::Vector{String} = String[],
                                 violation_types::Vector{ViolationType} = ViolationType[])
    LibPowsybl.add_operator_strategy(analysis.handle, operator_strategy_id, contingency_id,
                                     StdVector{StdString}(action_ids),
                                     LibPowsybl.ConditionType(condition_type),
                                     StdVector{StdString}(violation_subject_ids),
                                     StdVector{Cint}(Cint[Integer(v) for v in violation_types]))
    return nothing
  end

  """
      add_contingencies_from_json_file(analysis, json_file_path)

  Load contingencies described in a JSON file into the analysis context.
  """
  function add_contingencies_from_json_file(analysis::SecurityAnalysisContext, json_file_path::String)
    LibPowsybl.add_contingency_from_json_file(analysis.handle, json_file_path)
    return nothing
  end

  """
      add_actions_from_json_file(analysis, json_file_path)

  Load remedial actions described in a JSON file into the analysis context.
  """
  function add_actions_from_json_file(analysis::SecurityAnalysisContext, json_file_path::String)
    LibPowsybl.add_action_from_json_file(analysis.handle, json_file_path)
    return nothing
  end

  """
      add_operator_strategies_from_json_file(analysis, json_file_path)

  Load operator strategies described in a JSON file into the analysis context.
  """
  function add_operator_strategies_from_json_file(analysis::SecurityAnalysisContext, json_file_path::String)
    LibPowsybl.add_operator_strategy_from_json_file(analysis.handle, json_file_path)
    return nothing
  end

  function _run(analysis::SecurityAnalysisContext, network::Network.NetworkHandle,
                parameters, provider::String, dc::Bool, report_node)
    c_parameters = _to_c_parameters(_as_parameters(parameters))
    handle = report_node === nothing ?
      LibPowsybl.run_security_analysis(analysis.handle, network.handle, c_parameters, provider, dc) :
      LibPowsybl.run_security_analysis_report(analysis.handle, network.handle, c_parameters, provider, dc, report_node.handle)
    return Result(handle)
  end

  """
      run_ac(analysis, network[, parameters[, provider]]; report_node = nothing) -> Result

  Run the security analysis in AC. `parameters` are the security analysis parameters, or
  simply the load flow parameters to use for the base case and every contingency. Pass a
  `Powsybl.Report.ReportNode` as `report_node` to collect the functional logs.
  """
  function run_ac(analysis::SecurityAnalysisContext, network::Network.NetworkHandle,
                  parameters::Union{Parameters, LoadFlow.LoadFlowParameters} = Parameters(), provider::String = "";
                  report_node = nothing)
    return _run(analysis, network, parameters, provider, false, report_node)
  end

  """
      run_dc(analysis, network[, parameters[, provider]]; report_node = nothing) -> Result

  Run the security analysis in DC. See [`run_ac`](@ref).
  """
  function run_dc(analysis::SecurityAnalysisContext, network::Network.NetworkHandle,
                  parameters::Union{Parameters, LoadFlow.LoadFlowParameters} = Parameters(), provider::String = "";
                  report_node = nothing)
    return _run(analysis, network, parameters, provider, true, report_node)
  end

  """
      get_limit_violations(result::Result) -> DataFrame

  Return, as a DataFrame, all the limit violations detected in the base case and in each
  contingency (indexed by `contingency_id`, empty for the pre-contingency state).
  """
  function get_limit_violations(result::Result)
    series_array = LibPowsybl.get_security_analysis_limit_violations(result.handle)
    return Network.create_dataframe_from_series_array(series_array[])
  end

  """
      get_branch_results(result::Result) -> DataFrame

  Return the results on the monitored branches.
  """
  function get_branch_results(result::Result)
    series_array = LibPowsybl.get_security_analysis_branch_results(result.handle)
    return Network.create_dataframe_from_series_array(series_array[])
  end

  """
      get_bus_results(result::Result) -> DataFrame

  Return the results on the monitored buses.
  """
  function get_bus_results(result::Result)
    series_array = LibPowsybl.get_security_analysis_bus_results(result.handle)
    return Network.create_dataframe_from_series_array(series_array[])
  end

  """
      get_three_windings_transformer_results(result::Result) -> DataFrame

  Return the results on the monitored three windings transformers.
  """
  function get_three_windings_transformer_results(result::Result)
    series_array = LibPowsybl.get_security_analysis_three_windings_transformer_results(result.handle)
    return Network.create_dataframe_from_series_array(series_array[])
  end

  """
      get_pre_contingency_result(result::Result) -> ComputationStatus

  Return the computation status of the pre-contingency (base case) state.
  """
  function get_pre_contingency_result(result::Result)
    pre = LibPowsybl.get_pre_contingency_result(result.handle)
    return ComputationStatus(LibPowsybl.status(pre[]))
  end

  """
      get_post_contingency_results(result::Result) -> DataFrame

  Return a DataFrame with the computation status of each contingency
  (columns `contingency_id`, `status`).
  """
  function get_post_contingency_results(result::Result)
    c_results = LibPowsybl.get_post_contingency_results(result.handle)
    df = DataFrame()
    df[!, "contingency_id"] = [String(LibPowsybl.contingency_id(post_result)) for post_result in c_results]
    df[!, "status"] = [ComputationStatus(LibPowsybl.status(post_result)) for post_result in c_results]
    return df
  end

  """
      find_post_contingency_result(result::Result, contingency_id::String) -> ComputationStatus

  Return the computation status of a single contingency. Throws if the contingency is not
  part of the result.
  """
  function find_post_contingency_result(result::Result, contingency_id::String)
    for post_result in LibPowsybl.get_post_contingency_results(result.handle)
      if String(LibPowsybl.contingency_id(post_result)) == contingency_id
        return ComputationStatus(LibPowsybl.status(post_result))
      end
    end
    throw(KeyError(contingency_id))
  end

  """
      get_operator_strategy_results(result::Result) -> DataFrame

  Return a DataFrame with the outcome of each operator strategy
  (columns `operator_strategy_id`, `status`).
  """
  function get_operator_strategy_results(result::Result)
    os_results = LibPowsybl.get_operator_strategy_results(result.handle)
    df = DataFrame()
    df[!, "operator_strategy_id"] = [String(LibPowsybl.operator_strategy_id(os)) for os in os_results]
    df[!, "status"] = [ComputationStatus(LibPowsybl.status(os)) for os in os_results]
    return df
  end

  """
      find_operator_strategy_results(result::Result, operator_strategy_id::String) -> ComputationStatus

  Return the computation status of a single operator strategy. Throws if the strategy is
  not part of the result.
  """
  function find_operator_strategy_results(result::Result, operator_strategy_id::String)
    for os_result in LibPowsybl.get_operator_strategy_results(result.handle)
      if String(LibPowsybl.operator_strategy_id(os_result)) == operator_strategy_id
        return ComputationStatus(LibPowsybl.status(os_result))
      end
    end
    throw(KeyError(operator_strategy_id))
  end

  """
      get_operator_strategy_limit_violations(result::Result) -> DataFrame

  Return, as a DataFrame, the limit violations remaining after each operator strategy
  has been applied (indexed by `operator_strategy_id`). The `limit_type` column holds
  the ordinal of the Java `LimitViolationType`; `side` is a [`Side`](@ref).
  """
  function get_operator_strategy_limit_violations(result::Result)
    os_results = LibPowsybl.get_operator_strategy_results(result.handle)
    operator_strategy_id = String[]
    subject_id = String[]
    subject_name = String[]
    limit_type = Int[]
    limit_name = String[]
    limit = Float64[]
    acceptable_duration = Int[]
    limit_reduction = Float64[]
    value = Float64[]
    side = Side[]
    for os in os_results
      os_id = String(LibPowsybl.operator_strategy_id(os))
      for v in LibPowsybl.limit_violations(os)
        push!(operator_strategy_id, os_id)
        push!(subject_id, String(LibPowsybl.subject_id(v)))
        push!(subject_name, String(LibPowsybl.subject_name(v)))
        push!(limit_type, Int(LibPowsybl.limit_type(v)))
        push!(limit_name, String(LibPowsybl.limit_name(v)))
        push!(limit, LibPowsybl.limit(v))
        push!(acceptable_duration, Int(LibPowsybl.acceptable_duration(v)))
        push!(limit_reduction, LibPowsybl.limit_reduction(v))
        push!(value, LibPowsybl.value(v))
        push!(side, Side(LibPowsybl.side(v)))
      end
    end
    return DataFrame(; operator_strategy_id, subject_id, subject_name, limit_type, limit_name,
                     limit, acceptable_duration, limit_reduction, value, side)
  end

  """
      export_to_json(result::Result, json_file_path::String)

  Export the whole security analysis result to a JSON file.
  """
  function export_to_json(result::Result, json_file_path::String)
    LibPowsybl.security_analysis_result_to_json(result.handle, json_file_path)
    return nothing
  end

  """
      get_provider_names() -> Vector{String}

  Return the names of the available security analysis providers.
  """
  function get_provider_names()
    return [String(name) for name in LibPowsybl.get_security_analysis_provider_names()]
  end

  """
      set_default_provider(provider::String)

  Set the security analysis provider used when none is given to [`run_ac`](@ref) or
  [`run_dc`](@ref).
  """
  function set_default_provider(provider::String)
    LibPowsybl.set_default_security_analysis_provider(provider)
    return nothing
  end

  """
      get_default_provider() -> String

  Return the security analysis provider used when none is given.
  """
  get_default_provider() = String(LibPowsybl.get_default_security_analysis_provider())

  """
      get_provider_parameters_names(provider::String = "") -> Vector{String}

  Return the names of the parameters a security analysis provider accepts, to be used as
  the keys of the `provider_parameters` of [`Parameters`](@ref). Defaults to the provider
  returned by [`get_default_provider`](@ref).
  """
  function get_provider_parameters_names(provider::String = "")
    return [String(name) for name in LibPowsybl.get_security_analysis_provider_parameters_names(provider)]
  end
end
