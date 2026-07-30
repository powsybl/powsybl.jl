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
