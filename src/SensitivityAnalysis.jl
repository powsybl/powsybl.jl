# Copyright (c) 2026, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module SensitivityAnalysis
  using ..LibPowsybl
  using ..Network
  using ..LoadFlow
  using CxxWrap
  using DataFrames

  """
  The kind of monitored quantity a sensitivity factor is computed on (the "function").
  """
  @enum SensitivityFunctionType begin
    BRANCH_ACTIVE_POWER_1 = LibPowsybl.BRANCH_ACTIVE_POWER_1
    BRANCH_CURRENT_1 = LibPowsybl.BRANCH_CURRENT_1
    BRANCH_REACTIVE_POWER_1 = LibPowsybl.BRANCH_REACTIVE_POWER_1
    BRANCH_ACTIVE_POWER_2 = LibPowsybl.BRANCH_ACTIVE_POWER_2
    BRANCH_CURRENT_2 = LibPowsybl.BRANCH_CURRENT_2
    BRANCH_REACTIVE_POWER_2 = LibPowsybl.BRANCH_REACTIVE_POWER_2
    BRANCH_ACTIVE_POWER_3 = LibPowsybl.BRANCH_ACTIVE_POWER_3
    BRANCH_CURRENT_3 = LibPowsybl.BRANCH_CURRENT_3
    BRANCH_REACTIVE_POWER_3 = LibPowsybl.BRANCH_REACTIVE_POWER_3
    BUS_REACTIVE_POWER = LibPowsybl.BUS_REACTIVE_POWER
    BUS_VOLTAGE = LibPowsybl.BUS_VOLTAGE
  end

  """
  The kind of variable a sensitivity factor is computed against. `AUTO_DETECT` lets
  PowSyBl infer the variable type from the element id.
  """
  @enum SensitivityVariableType begin
    AUTO_DETECT = LibPowsybl.AUTO_DETECT
    INJECTION_ACTIVE_POWER = LibPowsybl.INJECTION_ACTIVE_POWER
    INJECTION_REACTIVE_POWER = LibPowsybl.INJECTION_REACTIVE_POWER
    TRANSFORMER_PHASE = LibPowsybl.TRANSFORMER_PHASE
    BUS_TARGET_VOLTAGE = LibPowsybl.BUS_TARGET_VOLTAGE
    HVDC_LINE_ACTIVE_POWER = LibPowsybl.HVDC_LINE_ACTIVE_POWER
    TRANSFORMER_PHASE_1 = LibPowsybl.TRANSFORMER_PHASE_1
    TRANSFORMER_PHASE_2 = LibPowsybl.TRANSFORMER_PHASE_2
    TRANSFORMER_PHASE_3 = LibPowsybl.TRANSFORMER_PHASE_3
  end

  """
  Selects for which contingencies a factor matrix is evaluated.
  """
  @enum ContingencyContextType begin
    ALL = LibPowsybl.CONTINGENCY_CONTEXT_ALL
    NONE = LibPowsybl.CONTINGENCY_CONTEXT_NONE
    SPECIFIC = LibPowsybl.CONTINGENCY_CONTEXT_SPECIFIC
    ONLY_CONTINGENCIES = LibPowsybl.CONTINGENCY_CONTEXT_ONLY_CONTINGENCIES
  end

  """
  Parameters of a sensitivity analysis run: the load flow parameters used for the base
  case and every contingency, the thresholds below which a computed sensitivity value is
  discarded, and the parameters specific to the sensitivity analysis provider.

  Every field is first read from the configuration, then overridden by the keywords given
  to [`Parameters`](@ref). The accepted keys of `provider_parameters` are listed by
  [`get_provider_parameters_names`](@ref).
  """
  mutable struct Parameters
    load_flow_parameters::LoadFlow.LoadFlowParameters
    flow_flow_sensitivity_value_threshold::Float64
    voltage_voltage_sensitivity_value_threshold::Float64
    flow_voltage_sensitivity_value_threshold::Float64
    angle_flow_sensitivity_value_threshold::Float64
    provider_parameters::Dict{String, String}
  end

  """
      Parameters(; load_flow_parameters, flow_flow_sensitivity_value_threshold,
                   voltage_voltage_sensitivity_value_threshold,
                   flow_voltage_sensitivity_value_threshold,
                   angle_flow_sensitivity_value_threshold, provider_parameters) -> Parameters

  Build the sensitivity analysis parameters, starting from the provider defaults.
  """
  function Parameters(; load_flow_parameters::Union{Nothing, LoadFlow.LoadFlowParameters} = nothing,
                        flow_flow_sensitivity_value_threshold::Union{Nothing, Real} = nothing,
                        voltage_voltage_sensitivity_value_threshold::Union{Nothing, Real} = nothing,
                        flow_voltage_sensitivity_value_threshold::Union{Nothing, Real} = nothing,
                        angle_flow_sensitivity_value_threshold::Union{Nothing, Real} = nothing,
                        provider_parameters::Union{Nothing, Dict{String, String}} = nothing)
    defaults = _default_parameters()
    return Parameters(load_flow_parameters === nothing ? defaults.load_flow_parameters : load_flow_parameters,
                      flow_flow_sensitivity_value_threshold === nothing ?
                        defaults.flow_flow_sensitivity_value_threshold : Float64(flow_flow_sensitivity_value_threshold),
                      voltage_voltage_sensitivity_value_threshold === nothing ?
                        defaults.voltage_voltage_sensitivity_value_threshold : Float64(voltage_voltage_sensitivity_value_threshold),
                      flow_voltage_sensitivity_value_threshold === nothing ?
                        defaults.flow_voltage_sensitivity_value_threshold : Float64(flow_voltage_sensitivity_value_threshold),
                      angle_flow_sensitivity_value_threshold === nothing ?
                        defaults.angle_flow_sensitivity_value_threshold : Float64(angle_flow_sensitivity_value_threshold),
                      provider_parameters === nothing ? defaults.provider_parameters : provider_parameters)
  end

  function _default_parameters()
    c_parameters = LibPowsybl.default_sensitivity_analysis_parameters()
    return Parameters(LoadFlow.c_parameters_to_julia_struct(LibPowsybl.loadflow_parameters(c_parameters)),
                      LibPowsybl.flow_flow_sensitivity_value_threshold(c_parameters),
                      LibPowsybl.voltage_voltage_sensitivity_value_threshold(c_parameters),
                      LibPowsybl.flow_voltage_sensitivity_value_threshold(c_parameters),
                      LibPowsybl.angle_flow_sensitivity_value_threshold(c_parameters),
                      Dict{String, String}())
  end

  function _to_c_parameters(parameters::Parameters)
    c_parameters = LibPowsybl.default_sensitivity_analysis_parameters()
    LibPowsybl.loadflow_parameters(c_parameters, LoadFlow.load_flow_parameters_to_c_struct(parameters.load_flow_parameters))
    LibPowsybl.flow_flow_sensitivity_value_threshold(c_parameters, parameters.flow_flow_sensitivity_value_threshold)
    LibPowsybl.voltage_voltage_sensitivity_value_threshold(c_parameters, parameters.voltage_voltage_sensitivity_value_threshold)
    LibPowsybl.flow_voltage_sensitivity_value_threshold(c_parameters, parameters.flow_voltage_sensitivity_value_threshold)
    LibPowsybl.angle_flow_sensitivity_value_threshold(c_parameters, parameters.angle_flow_sensitivity_value_threshold)
    LibPowsybl.provider_parameters_keys(c_parameters, StdVector{StdString}(collect(keys(parameters.provider_parameters))))
    LibPowsybl.provider_parameters_values(c_parameters, StdVector{StdString}(collect(values(parameters.provider_parameters))))
    return c_parameters
  end

  """
  A sensitivity analysis context: it collects factor matrices (and optionally
  contingencies) to evaluate before being run against a network.
  """
  abstract type SensitivityAnalysisContext end

  # Per matrix id, the labels of the result columns (the monitored functions) and of the
  # result rows (the variables). The C layer returns bare numbers, so the labels have to be
  # remembered here and handed to the result at run time.
  mutable struct AcSensitivityAnalysisContext <: SensitivityAnalysisContext
    handle::LibPowsybl.JavaHandle
    function_ids::Dict{String, Vector{String}}
    row_labels::Dict{String, Vector{String}}
  end

  mutable struct DcSensitivityAnalysisContext <: SensitivityAnalysisContext
    handle::LibPowsybl.JavaHandle
    function_ids::Dict{String, Vector{String}}
    row_labels::Dict{String, Vector{String}}
  end

  """
  The result of a sensitivity analysis run. Query it through `get_sensitivity_matrix`
  and `get_reference_matrix`.
  """
  mutable struct Result
    handle::LibPowsybl.JavaHandle
    function_ids::Dict{String, Vector{String}}
    row_labels::Dict{String, Vector{String}}
  end

  """
      create_ac_analysis() -> AcSensitivityAnalysisContext

  Create an empty sensitivity analysis to be run in AC. Bus voltage sensitivities are only
  available in AC, hence the distinct context.
  """
  create_ac_analysis() = AcSensitivityAnalysisContext(LibPowsybl.create_sensitivity_analysis(),
                                                      Dict{String, Vector{String}}(),
                                                      Dict{String, Vector{String}}())

  """
      create_dc_analysis() -> DcSensitivityAnalysisContext

  Create an empty sensitivity analysis to be run in DC, the usual mode for PTDF
  computations.
  """
  create_dc_analysis() = DcSensitivityAnalysisContext(LibPowsybl.create_sensitivity_analysis(),
                                                      Dict{String, Vector{String}}(),
                                                      Dict{String, Vector{String}}())

  """
      add_single_element_contingency(analysis, element_id[, contingency_id])

  Add a contingency tripping a single element (used to compute post-contingency
  sensitivities). Defaults the contingency id to the element id.
  """
  function add_single_element_contingency(analysis::SensitivityAnalysisContext, element_id::String, contingency_id::String = element_id)
    LibPowsybl.add_sensitivity_contingency(analysis.handle, contingency_id, StdVector{StdString}([element_id]))
    return nothing
  end

  """
      add_multiple_elements_contingency(analysis, elements_ids, contingency_id)

  Add a contingency tripping several elements simultaneously.
  """
  function add_multiple_elements_contingency(analysis::SensitivityAnalysisContext, elements_ids::Vector{String}, contingency_id::String)
    LibPowsybl.add_sensitivity_contingency(analysis.handle, contingency_id, StdVector{StdString}(elements_ids))
    return nothing
  end

  """
      add_single_element_contingencies(analysis, elements_ids; contingency_id_provider = nothing)

  Add one single-element contingency per element id. `contingency_id_provider` maps an
  element id to the id of its contingency; when omitted the element id is used.
  """
  function add_single_element_contingencies(analysis::SensitivityAnalysisContext, elements_ids::Vector{String};
                                            contingency_id_provider = nothing)
    for element_id in elements_ids
      contingency_id = contingency_id_provider === nothing ? element_id : contingency_id_provider(element_id)
      add_single_element_contingency(analysis, element_id, contingency_id)
    end
    return nothing
  end

  """
      add_contingencies_from_json_file(analysis, path_to_json_file)

  Add every contingency described by a JSON contingency list file.
  """
  function add_contingencies_from_json_file(analysis::SensitivityAnalysisContext, path_to_json_file::String)
    LibPowsybl.add_sensitivity_contingencies_from_json_file(analysis.handle, path_to_json_file)
    return nothing
  end

  """
      add_factor_matrix(analysis, function_ids, variable_ids; matrix_id, contingencies_ids,
                        contingency_context_type, sensitivity_function_type,
                        sensitivity_variable_type)

  Register a factor matrix: sensitivities of each monitored quantity in `function_ids`
  (e.g. branch ids) with respect to each variable in `variable_ids` (e.g. injections).
  The matrix is retrieved after the run via its `matrix_id` (default `"default"`).
  """
  function add_factor_matrix(analysis::SensitivityAnalysisContext, function_ids::Vector{String}, variable_ids::AbstractVector;
                             matrix_id::String = "default",
                             contingencies_ids::Vector{String} = String[],
                             contingency_context_type::ContingencyContextType = ALL,
                             sensitivity_function_type::SensitivityFunctionType = BRANCH_ACTIVE_POWER_1,
                             sensitivity_variable_type::SensitivityVariableType = AUTO_DETECT)
    flattened_variable_ids, row_labels = _process_variable_ids(variable_ids)
    LibPowsybl.add_factor_matrix(analysis.handle, matrix_id,
                                 StdVector{StdString}(function_ids),
                                 StdVector{StdString}(flattened_variable_ids),
                                 StdVector{StdString}(contingencies_ids),
                                 Int32(contingency_context_type),
                                 Int32(sensitivity_function_type),
                                 Int32(sensitivity_variable_type))
    analysis.function_ids[matrix_id] = copy(function_ids)
    analysis.row_labels[matrix_id] = row_labels
    return nothing
  end

  # Marks the second row of a power transfer, which is folded into the first one and
  # dropped when the result is built.
  const _TRANSFER_SECOND_ROW = "\0transfer_second_row"

  # A variable is either an element or zone id, or a pair of zone ids standing for a
  # transfer between them. A transfer is sent as its two ids in a row and shows up as a
  # single row, the sensitivity of the first zone minus that of the second.
  function _process_variable_ids(variable_ids::AbstractVector)
    flattened = String[]
    labels = String[]
    for variable_id in variable_ids
      if variable_id isa AbstractString
        push!(flattened, String(variable_id))
        push!(labels, String(variable_id))
      elseif variable_id isa Tuple || variable_id isa Pair
        pair = variable_id isa Pair ? (variable_id.first, variable_id.second) : variable_id
        length(pair) == 2 ||
          throw(ArgumentError("a power transfer variable is a pair of zone ids, got $(length(pair)) ids"))
        first_id, second_id = String(pair[1]), String(pair[2])
        push!(flattened, first_id)
        push!(flattened, second_id)
        push!(labels, first_id * " -> " * second_id)
        push!(labels, _TRANSFER_SECOND_ROW)
      else
        throw(ArgumentError("unsupported variable id $(repr(variable_id)); expected an id " *
                            "or a pair of zone ids describing a transfer"))
      end
    end
    return flattened, labels
  end

  """
      add_branch_flow_factor_matrix(analysis, branch_ids, variable_ids; matrix_id = "default")

  Register a branch active power (side 1) factor matrix, evaluated on the base case and on
  every contingency.
  """
  function add_branch_flow_factor_matrix(analysis::SensitivityAnalysisContext, branch_ids::Vector{String},
                                         variable_ids::AbstractVector; matrix_id::String = "default")
    return add_factor_matrix(analysis, branch_ids, variable_ids;
                             matrix_id = matrix_id,
                             contingency_context_type = ALL,
                             sensitivity_function_type = BRANCH_ACTIVE_POWER_1,
                             sensitivity_variable_type = AUTO_DETECT)
  end

  """
      add_precontingency_branch_flow_factor_matrix(analysis, branch_ids, variable_ids; matrix_id = "default")

  Register a branch active power (side 1) factor matrix evaluated on the base case only.
  """
  function add_precontingency_branch_flow_factor_matrix(analysis::SensitivityAnalysisContext, branch_ids::Vector{String},
                                                        variable_ids::AbstractVector; matrix_id::String = "default")
    return add_factor_matrix(analysis, branch_ids, variable_ids;
                             matrix_id = matrix_id,
                             contingency_context_type = NONE,
                             sensitivity_function_type = BRANCH_ACTIVE_POWER_1,
                             sensitivity_variable_type = AUTO_DETECT)
  end

  """
      add_postcontingency_branch_flow_factor_matrix(analysis, branch_ids, variable_ids, contingencies_ids;
                                                    matrix_id = "default")

  Register a branch active power (side 1) factor matrix evaluated on the given
  contingencies only.
  """
  function add_postcontingency_branch_flow_factor_matrix(analysis::SensitivityAnalysisContext, branch_ids::Vector{String},
                                                         variable_ids::AbstractVector, contingencies_ids::Vector{String};
                                                         matrix_id::String = "default")
    return add_factor_matrix(analysis, branch_ids, variable_ids;
                             matrix_id = matrix_id,
                             contingencies_ids = contingencies_ids,
                             contingency_context_type = SPECIFIC,
                             sensitivity_function_type = BRANCH_ACTIVE_POWER_1,
                             sensitivity_variable_type = AUTO_DETECT)
  end

  # Load flow parameters alone are accepted too, the rest of the sensitivity analysis
  # parameters then keeping their default values.
  _as_parameters(parameters::Parameters) = parameters
  _as_parameters(parameters::LoadFlow.LoadFlowParameters) = Parameters(load_flow_parameters = parameters)

  """
      add_bus_voltage_factor_matrix(analysis, bus_ids, target_voltage_ids; matrix_id = "default")

  Register the sensitivities of the voltage of `bus_ids` to the voltage target of
  `target_voltage_ids`. Only meaningful in AC, hence only on an AC context.
  """
  function add_bus_voltage_factor_matrix(analysis::AcSensitivityAnalysisContext, bus_ids::Vector{String},
                                         target_voltage_ids::AbstractVector; matrix_id::String = "default")
    return add_factor_matrix(analysis, bus_ids, target_voltage_ids;
                             matrix_id = matrix_id,
                             contingency_context_type = ALL,
                             sensitivity_function_type = BUS_VOLTAGE,
                             sensitivity_variable_type = BUS_TARGET_VOLTAGE)
  end

  function _run(analysis::SensitivityAnalysisContext, network::Network.NetworkHandle, dc::Bool,
                parameters, provider::String, report_node)
    c_parameters = _to_c_parameters(_as_parameters(parameters))
    handle = report_node === nothing ?
      LibPowsybl.run_sensitivity_analysis(analysis.handle, network.handle, dc, c_parameters, provider) :
      LibPowsybl.run_sensitivity_analysis_report(analysis.handle, network.handle, dc, c_parameters, provider, report_node.handle)
    return Result(handle, copy(analysis.function_ids), copy(analysis.row_labels))
  end

  """
      run(analysis, network[, parameters[, provider]]; report_node = nothing) -> Result

  Run the sensitivity analysis. The context decides the mode: an AC context runs in AC, a
  DC context in DC. `parameters` are the sensitivity analysis parameters, or simply the
  load flow parameters to use. Pass a `Powsybl.Report.ReportNode` as `report_node` to
  collect the functional logs.
  """
  function run(analysis::AcSensitivityAnalysisContext, network::Network.NetworkHandle,
               parameters::Union{Parameters, LoadFlow.LoadFlowParameters} = Parameters(), provider::String = "";
               report_node = nothing)
    return _run(analysis, network, false, parameters, provider, report_node)
  end

  function run(analysis::DcSensitivityAnalysisContext, network::Network.NetworkHandle,
               parameters::Union{Parameters, LoadFlow.LoadFlowParameters} = Parameters(), provider::String = "";
               report_node = nothing)
    return _run(analysis, network, true, parameters, provider, report_node)
  end

  function _matrix_to_julia(m)
    row_count = LibPowsybl.row_count(m)
    column_count = LibPowsybl.column_count(m)
    # The C matrix is row-major; reshape column-major then transpose to recover it.
    values = collect(Float64, LibPowsybl.matrix_values(m))
    return permutedims(reshape(values, column_count, row_count))
  end

  """
      get_sensitivity_matrix(result[, matrix_id[, contingency_id]]) -> DataFrame

  Return the sensitivity values of a factor matrix (default `matrix_id = "default"`) for a
  given contingency (empty id for the base case). The first column, `id`, names the
  variable of each row; the remaining columns are the monitored functions.

  A variable registered as a power transfer between two zones appears as the single row
  `"zone1 -> zone2"`, holding the sensitivity of the first zone minus that of the second.
  """
  function get_sensitivity_matrix(result::Result, matrix_id::String = "default", contingency_id::String = "")
    values = get_sensitivity_values(result, matrix_id, contingency_id)
    labels = _labels_of(result, matrix_id, size(values, 1))
    values, labels = _fold_transfers(values, labels)
    return _to_dataframe(values, labels, _function_ids_of(result, matrix_id, size(values, 2)))
  end

  """
      get_reference_matrix(result[, matrix_id[, contingency_id]];
                           reference_column_id = "reference_values") -> DataFrame

  Return the reference values of a factor matrix, the quantities the sensitivities are
  computed around, as a single row named by `reference_column_id`.
  """
  function get_reference_matrix(result::Result, matrix_id::String = "default", contingency_id::String = "";
                                reference_column_id::String = "reference_values")
    values = get_reference_values(result, matrix_id, contingency_id)
    return _to_dataframe(values, fill(reference_column_id, size(values, 1)),
                         _function_ids_of(result, matrix_id, size(values, 2)))
  end

  """
      get_sensitivity_values(result[, matrix_id[, contingency_id]]) -> Matrix{Float64}

  The sensitivity values without their labels, one row per variable and one column per
  monitored function. Power transfers are left as their two separate rows.
  """
  function get_sensitivity_values(result::Result, matrix_id::String = "default", contingency_id::String = "")
    return _matrix_to_julia(LibPowsybl.get_sensitivity_matrix(result.handle, matrix_id, contingency_id)[])
  end

  """
      get_reference_values(result[, matrix_id[, contingency_id]]) -> Matrix{Float64}

  The reference values without their labels.
  """
  function get_reference_values(result::Result, matrix_id::String = "default", contingency_id::String = "")
    return _matrix_to_julia(LibPowsybl.get_reference_matrix(result.handle, matrix_id, contingency_id)[])
  end

  # Falls back to positional names when a matrix was registered outside this context, so a
  # result is still readable rather than throwing.
  function _labels_of(result::Result, matrix_id::String, row_count::Int)
    labels = get(result.row_labels, matrix_id, String[])
    return length(labels) == row_count ? labels : ["row_$i" for i in 1:row_count]
  end

  function _function_ids_of(result::Result, matrix_id::String, column_count::Int)
    ids = get(result.function_ids, matrix_id, String[])
    return length(ids) == column_count ? ids : ["column_$i" for i in 1:column_count]
  end

  # A power transfer was sent as two variables; its value is the difference between them,
  # so fold the second row into the first and drop it.
  function _fold_transfers(values::Matrix{Float64}, labels::Vector{String})
    _TRANSFER_SECOND_ROW in labels || return values, labels
    kept = Int[]
    for (row, label) in enumerate(labels)
      if label == _TRANSFER_SECOND_ROW
        isempty(kept) && throw(ArgumentError("a power transfer second row has no first row"))
        values[kept[end], :] .-= values[row, :]
      else
        push!(kept, row)
      end
    end
    return values[kept, :], labels[kept]
  end

  function _to_dataframe(values::Matrix{Float64}, labels::Vector{String}, function_ids::Vector{String})
    frame = DataFrame()
    frame[!, "id"] = labels
    for (column, function_id) in enumerate(function_ids)
      frame[!, function_id] = values[:, column]
    end
    return frame
  end

  """
      get_provider_names() -> Vector{String}

  Return the names of the available sensitivity analysis providers.
  """
  function get_provider_names()
    return [String(name) for name in LibPowsybl.get_sensitivity_analysis_provider_names()]
  end

  """
      set_default_provider(provider::String)

  Set the sensitivity analysis provider used when none is given to [`run_ac`](@ref) or
  [`run_dc`](@ref).
  """
  function set_default_provider(provider::String)
    LibPowsybl.set_default_sensitivity_analysis_provider(provider)
    return nothing
  end

  """
      get_default_provider() -> String

  Return the sensitivity analysis provider used when none is given.
  """
  get_default_provider() = String(LibPowsybl.get_default_sensitivity_analysis_provider())

  """
      get_provider_parameters_names(provider::String = "") -> Vector{String}

  Return the names of the parameters a sensitivity analysis provider accepts. Defaults to
  the provider returned by [`get_default_provider`](@ref).
  """
  function get_provider_parameters_names(provider::String = "")
    return [String(name) for name in LibPowsybl.get_sensitivity_analysis_provider_parameters_names(provider)]
  end
end
