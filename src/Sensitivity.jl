module Sensitivity
  using ..LibPowsybl
  using ..Network
  using DataFrames
  using CxxWrap

  mutable struct Analysis
    handle::LibPowsybl.JavaHandle
  end

  mutable struct Zone
    id::String
    shift_keys_by_injections_ids::Dict{String, Float64}
  end

  @enum ContingencyContextType begin
    ALL=LibPowsybl.ALL
    NONE=LibPowsybl.NONE
    SPECIFIC=LibPowsybl.SPECIFIC
    ONLY_CONTINGENCIES=LibPowsybl.ONLY_CONTINGENCIES
  end

  @enum SensitivityFunctionType begin
    BRANCH_ACTIVE_POWER_1=LibPowsybl.BRANCH_ACTIVE_POWER_1
    BRANCH_CURRENT_1=LibPowsybl.BRANCH_CURRENT_1
    BRANCH_REACTIVE_POWER_1=LibPowsybl.BRANCH_REACTIVE_POWER_1
    BRANCH_ACTIVE_POWER_2=LibPowsybl.BRANCH_ACTIVE_POWER_2
    BRANCH_CURRENT_2=LibPowsybl.BRANCH_CURRENT_2
    BRANCH_REACTIVE_POWER_2=LibPowsybl.BRANCH_REACTIVE_POWER_2
    BRANCH_ACTIVE_POWER_3=LibPowsybl.BRANCH_ACTIVE_POWER_3
    BRANCH_CURRENT_3=LibPowsybl.BRANCH_CURRENT_3
    BRANCH_REACTIVE_POWER_3=LibPowsybl.BRANCH_REACTIVE_POWER_3
  end

  @enum SensitivityVariableType begin
    AUTO_DETECT=LibPowsybl.AUTO_DETECT
    INJECTION_ACTIVE_POWER=LibPowsybl.INJECTION_ACTIVE_POWER
    INJECTION_REACTIVE_POWER=LibPowsybl.INJECTION_REACTIVE_POWER
    TRANSFORMER_PHASE=LibPowsybl.TRANSFORMER_PHASE
    BUS_TARGET_VOLTAGE=LibPowsybl.BUS_TARGET_VOLTAGE
    HVDC_LINE_ACTIVE_POWER=LibPowsybl.HVDC_LINE_ACTIVE_POWER
    TRANSFORMER_PHASE_1=LibPowsybl.TRANSFORMER_PHASE_1
    TRANSFORMER_PHASE_2=LibPowsybl.TRANSFORMER_PHASE_2
    TRANSFORMER_PHASE_3=LibPowsybl.TRANSFORMER_PHASE_3
  end

  function create_sensitivity_analysis()
      return Analysis(LibPowsybl.create_sensitivity_analysis())
  end

  function set_zones(analysis::Analysis, zones::Vector{Zone})
      internal_zones = []
      for zone in zones
        injection_ids = collect(keys(zone.shift_keys_by_injections_ids))
        shift_keys = collect(values(zone.shift_keys_by_injections_ids))
        internal_zone = LibPowsybl.Zone(zone.id, StdVector{StdString}(injection_ids), StdVector{Float64}(shift_keys))
        push!(internal_zones, internal_zone)
      end
      LibPowsybl.set_zones(analysis.handle, internal_zones)
  end

  function add_factor_matrix(analysis::Analysis, functions_ids::Vector{String}, variable_ids::Vector{String}, contingencies_ids::Vector{String},
      contingency_context::ContingencyContextType, sensitivity_function::SensitivityFunctionType, sensitivity_variable::SensitivityVariableType,
      matrix_id::String = "default")
      LibPowsybl.add_factor_matrix(analysis.handle, matrix_id, functions_ids, variable_ids, contingencies_ids,
       LibPowsybl.ContingencyContextType(contingency_context), LibPowsybl.SensitivityFunctionType(sensitivity_function),
       LibPowsybl.SensitivityVariableType(sensitivity_variable))
  end

  function add_single_element_contingency()
  end

  function add_multiple_elements_contingency()
  end

  function add_single_element_contingencies()
  end
end