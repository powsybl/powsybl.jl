module LoadFlow
  using ..LibPowsybl
  using ..Network
  using DataFrames
  using CxxWrap

  @enum VoltageInitMode begin
    UNIFORM_VALUES=LibPowsybl.UNIFORM_VALUES
    PREVIOUS_VALUES=LibPowsybl.PREVIOUS_VALUES
    DC_VALUES=LibPowsybl.DC_VALUES
  end

  @enum LoadFlowComponentStatus begin
    CONVERGED=LibPowsybl.CONVERGED
    FAILED=LibPowsybl.FAILED
    MAX_ITERATION_REACHED=LibPowsybl.MAX_ITERATION_REACHED
    NO_CALCULATION=LibPowsybl.NO_CALCULATION
  end

  @enum BalanceType begin
    PROPORTIONAL_TO_GENERATION_P=LibPowsybl.PROPORTIONAL_TO_GENERATION_P
    PROPORTIONAL_TO_GENERATION_P_MAX=LibPowsybl.PROPORTIONAL_TO_GENERATION_P_MAX
    PROPORTIONAL_TO_GENERATION_REMAINING_MARGIN=LibPowsybl.PROPORTIONAL_TO_GENERATION_REMAINING_MARGIN
    PROPORTIONAL_TO_GENERATION_PARTICIPATION_FACTOR=LibPowsybl.PROPORTIONAL_TO_GENERATION_PARTICIPATION_FACTOR
    PROPORTIONAL_TO_LOAD=LibPowsybl.PROPORTIONAL_TO_LOAD
    PROPORTIONAL_TO_CONFORM_LOAD=LibPowsybl.PROPORTIONAL_TO_CONFORM_LOAD

  end

  @enum ComponentMode begin
    MAIN_CONNECTED=LibPowsybl.MAIN_CONNECTED
    ALL_CONNECTED=LibPowsybl.ALL_CONNECTED
    MAIN_SYNCHRONOUS=LibPowsybl.MAIN_SYNCHRONOUS
  end

  mutable struct LoadFlowParameters
      voltage_init_mode::VoltageInitMode
      transformer_voltage_control_on::Bool
      use_reactive_limits::Bool
      phase_shifter_regulation_on::Bool
      twt_split_shunt_admittance::Bool
      shunt_compensator_voltage_control_on::Bool
      read_slack_bus::Bool
      write_slack_bus::Bool
      distributed_slack::Bool
      balance_type::BalanceType
      dc_use_transformer_ratio::Bool
      countries_to_balance::Vector{String}
      component_mode::ComponentMode
      dc_power_factor::Float64
      provider_parameters::Dict{String, String}
  end

  mutable struct Result
      component_results::DataFrame
      slack_bus_results::DataFrame
  end

  function load_flow_parameters_to_c_struct(parameters::LoadFlowParameters)
      c_parameters = LibPowsybl.LoadFlowParameters()
      LibPowsybl.voltage_init_mode(c_parameters, LibPowsybl.VoltageInitMode(parameters.voltage_init_mode))
      LibPowsybl.transformer_voltage_control_on(c_parameters, parameters.transformer_voltage_control_on)
      LibPowsybl.use_reactive_limits(c_parameters, parameters.use_reactive_limits)
      LibPowsybl.phase_shifter_regulation_on(c_parameters, parameters.phase_shifter_regulation_on)
      LibPowsybl.twt_split_shunt_admittance(c_parameters, parameters.twt_split_shunt_admittance)
      LibPowsybl.shunt_compensator_voltage_control_on(c_parameters, parameters.shunt_compensator_voltage_control_on)
      LibPowsybl.read_slack_bus(c_parameters, parameters.read_slack_bus)
      LibPowsybl.write_slack_bus(c_parameters, parameters.write_slack_bus)
      LibPowsybl.distributed_slack(c_parameters, parameters.distributed_slack)
      LibPowsybl.balance_type(c_parameters, LibPowsybl.BalanceType(parameters.balance_type))
      LibPowsybl.dc_use_transformer_ratio(c_parameters, parameters.dc_use_transformer_ratio)
      LibPowsybl.countries_to_balance(c_parameters, StdVector{StdString}(parameters.countries_to_balance))
      LibPowsybl.component_mode(c_parameters, LibPowsybl.ComponentMode(parameters.component_mode))
      LibPowsybl.dc_power_factor(c_parameters, parameters.dc_power_factor)
      LibPowsybl.provider_parameters_keys(c_parameters, StdVector{StdString}(collect(keys(parameters.provider_parameters))))
      LibPowsybl.provider_parameters_values(c_parameters, StdVector{StdString}(collect(values(parameters.provider_parameters))))
      return c_parameters
  end

  function c_parameters_to_julia_struct(parameters::LibPowsybl.LoadFlowParameters)
      return LoadFlowParameters(
        VoltageInitMode(LibPowsybl.voltage_init_mode(parameters)),
        LibPowsybl.transformer_voltage_control_on(parameters),
        LibPowsybl.use_reactive_limits(parameters),
        LibPowsybl.phase_shifter_regulation_on(parameters),
        LibPowsybl.twt_split_shunt_admittance(parameters),
        LibPowsybl.shunt_compensator_voltage_control_on(parameters),
        LibPowsybl.read_slack_bus(parameters),
        LibPowsybl.write_slack_bus(parameters),
        LibPowsybl.distributed_slack(parameters),
        BalanceType(LibPowsybl.balance_type(parameters)),
        LibPowsybl.dc_use_transformer_ratio(parameters),
        LibPowsybl.countries_to_balance(parameters),
        ComponentMode(LibPowsybl.component_mode(parameters)),
        LibPowsybl.dc_power_factor(parameters),
        Dict{String, String}())
  end

  function load_flow_results_to_dataframe(component_results)
      df_components = DataFrame()
      df_components[!, "connected_component_num"] = [LibPowsybl.connected_component_num(result) for result in component_results]
      df_components[!, "synchronous_component_num"] = [LibPowsybl.synchronous_component_num(result) for result in component_results]
      df_components[!, "status"] = [LoadFlowComponentStatus(LibPowsybl.status(result)) for result in component_results]
      df_components[!, "status_text"] = [String(LibPowsybl.status_text(result)) for result in component_results]
      df_components[!, "iteration_count"] = [LibPowsybl.iteration_count(result) for result in component_results]
      df_components[!, "reference_bus_id"] = [String(LibPowsybl.reference_bus_id(result)) for result in component_results]
      df_components[!, "distributed_active_power"] = [LibPowsybl.distributed_active_power(result) for result in component_results]

      cc_serie = []
      sc_serie = []
      id_serie = []
      active_power_mismatch_serie = []
      for result in component_results
        cc = LibPowsybl.connected_component_num(result)
        sc = LibPowsybl.synchronous_component_num(result)
        for slack_bus_result in LibPowsybl.slack_bus_results(result)
          push!(cc_serie, cc)
          push!(sc_serie, sc)
          push!(id_serie, String(LibPowsybl.id(slack_bus_result)))
          push!(active_power_mismatch_serie, LibPowsybl.active_power_mismatch(slack_bus_result))
        end
      end

      df_slack_bus = DataFrame()
      df_slack_bus[!, "connected_component_num"] = cc_serie
      df_slack_bus[!, "synchronous_component_num"] = sc_serie
      df_slack_bus[!, "id"] = id_serie
      df_slack_bus[!, "active_power_mismatch"] = active_power_mismatch_serie
      return Result(df_components, df_slack_bus)
  end

  function load_flow_parameters()
      return c_parameters_to_julia_struct(LibPowsybl.LoadFlowParameters())
  end

  function run_ac(network::Network.NetworkHandle, parameters::LoadFlowParameters, provider::String = "")
      load_flow_c_result = LibPowsybl.run_load_flow(network.handle, load_flow_parameters_to_c_struct(parameters), false, provider)
      return load_flow_results_to_dataframe(load_flow_c_result)
  end

  function run_dc(network::Network.NetworkHandle, parameters::LoadFlowParameters, provider::String = "")
      load_flow_c_result = LibPowsybl.run_load_flow(network.handle, load_flow_parameters_to_c_struct(parameters), true, provider)
      return load_flow_results_to_dataframe(load_flow_c_result)
  end

  function get_provider_parameters(provider::String = "")
      return Network.create_dataframe_from_series_array(LibPowsybl.create_loadflow_provider_parameters_series_array(provider))
  end
end