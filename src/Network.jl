# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Network
  using ..LibPowsybl
  using CxxWrap
  using DataFrames

  nominal_apparent_power::Float64 = 100.0
  per_unit::Bool = false

  mutable struct NetworkHandle
    handle::LibPowsybl.JavaHandle
    id::String
    name::String
    source_format::String
    forecast_distance::Int32
    case_date::Float64
  end

  function get_network_metadata(network::NetworkHandle)
      return LibPowsybl.get_network_metadata(network.handle)
  end

  function get_network_import_formats()
      return [String(format) for format in LibPowsybl.get_network_import_formats()]
  end

  function get_network_export_formats()
      return [String(format) for format in LibPowsybl.get_network_export_formats()]
  end

  function get_network_available_post_processors()
      return [String(processor) for processor in LibPowsybl.get_network_available_post_processors()]
  end

  function get_extensions_names()
      return [String(extension_name) for extension_name in LibPowsybl.get_extensions_names()]
  end

  function get_elements(network::NetworkHandle, type::LibPowsybl.ElementType, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    filter_attributes = LibPowsybl.DEFAULT_ATTRIBUTES
    if all_attributes
      filter_attributes = LibPowsybl.ALL_ATTRIBUTES
    elseif !isempty(attributes)
      filter_attributes = LibPowsybl.SELECTION_ATTRIBUTES
    end

    if all_attributes && !isempty(attributes)
      throw("parameters \"all_attributes\" and \"attributes\" are mutually exclusive")
    end
    series_array = LibPowsybl.create_network_elements_series_array(network.handle, type, StdVector{StdString}(attributes), filter_attributes, per_unit, nominal_apparent_power)
    return create_dataframe_from_series_array(series_array[])
  end

  function get_buses(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BUS, all_attributes, attributes)
  end

  function get_bus_breaker_view_buses(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BUS_FROM_BUS_BREAKER_VIEW, all_attributes, attributes)
  end

  function get_generators(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.GENERATOR, all_attributes, attributes)
  end

  function get_batteries(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BATTERY, all_attributes, attributes)
  end

  function get_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.LINE, all_attributes, attributes)
  end

  function get_2_windings_transformers(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.TWO_WINDINGS_TRANSFORMER, all_attributes, attributes)
  end

  function get_3_windings_transformers(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.THREE_WINDINGS_TRANSFORMER, all_attributes, attributes)
  end

  function get_shunt_compensators(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.SHUNT_COMPENSATOR, all_attributes, attributes)
  end

  function get_non_linear_shunt_compensator_sections(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.NON_LINEAR_SHUNT_COMPENSATOR_SECTION, all_attributes, attributes)
  end

  function get_linear_shunt_compensator_sections(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.LINEAR_SHUNT_COMPENSATOR_SECTION, all_attributes, attributes)
  end

  function get_boundary_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BOUNDARY_LINE, all_attributes, attributes)
  end

  # Deprecated: dangling lines are now called boundary lines. Kept as an alias for backward
  # compatibility; use get_boundary_lines instead.
  function get_dangling_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    Base.depwarn("get_dangling_lines is deprecated, use get_boundary_lines instead.", :get_dangling_lines)
    return get_boundary_lines(network, all_attributes, attributes)
  end

  function get_tie_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.TIE_LINE, all_attributes, attributes)
  end

  function get_lcc_converter_stations(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.LCC_CONVERTER_STATION, all_attributes, attributes)
  end

  function get_vsc_converter_stations(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.VSC_CONVERTER_STATION, all_attributes, attributes)
  end

  function get_static_var_compensators(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.STATIC_VAR_COMPENSATOR, all_attributes, attributes)
  end

  function get_voltage_levels(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.VOLTAGE_LEVEL, all_attributes, attributes)
  end

  function get_busbar_sections(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BUSBAR_SECTION, all_attributes, attributes)
  end

  function get_substations(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.SUBSTATION, all_attributes, attributes)
  end

  function get_hvdc_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.HVDC_LINE, all_attributes, attributes)
  end

  function get_switches(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.SWITCH, all_attributes, attributes)
  end

  function get_ratio_tap_changer_steps(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.RATIO_TAP_CHANGER_STEP, all_attributes, attributes)
  end

  function get_phase_tap_changer_steps(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.PHASE_TAP_CHANGER_STEP, all_attributes, attributes)
  end

  function get_ratio_tap_changers(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.RATIO_TAP_CHANGER, all_attributes, attributes)
  end

  function get_phase_tap_changers(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.PHASE_TAP_CHANGER, all_attributes, attributes)
  end

  function get_reactive_capability_curve_points(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.REACTIVE_CAPABILITY_CURVE_POINT, all_attributes, attributes)
  end

  function get_aliases(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.ALIAS, all_attributes, attributes)
  end

  function get_identifiables(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.IDENTIFIABLE, all_attributes, attributes)
  end

  function get_injections(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.INJECTION, all_attributes, attributes)
  end

  function get_branches(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BRANCH, all_attributes, attributes)
  end

  function get_terminals(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.TERMINAL, all_attributes, attributes)
  end

  function get_loads(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.LOAD, all_attributes, attributes)
  end

  function get_operational_limits(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.OPERATIONAL_LIMITS, all_attributes, attributes)
  end

  function get_extensions(network::NetworkHandle, extension_name::String, table_name::String = "")
    series_array = LibPowsybl.create_network_elements_extension_series_array(network.handle, extension_name, table_name)
    return create_dataframe_from_series_array(series_array[])
  end

  function create_dataframe_from_series_array(array::LibPowsybl.SeriesArray)
    myArray = LibPowsybl.as_array(array)
    df = DataFrame()
    for serie in myArray
      type = LibPowsybl.type(serie)
      name = LibPowsybl.name(serie)
      if type == 0
        # To avoid getting CxxWrap StdString type in the dataframe
        data = [String(cxx_str_elem) for cxx_str_elem in LibPowsybl.as_string_array(serie)]
      elseif type == 1
        data = LibPowsybl.as_double_array(serie)
      elseif type == 2
        data = LibPowsybl.as_int_array(serie)
      elseif type == 3
        # To avoid getting CxxWrap CxxBool type in the dataframe
        data = [Bool(cxx_bool_elem) for cxx_bool_elem in LibPowsybl.as_bool_array(serie)]
      else
        continue
      end
      df[!, name]=data
    end
    return df
  end

  function load(network_file::String, parameters::Dict{String, String} = Dict{String, String}(), postProcessors::Vector{String} = Vector{String}())::NetworkHandle
      handle = LibPowsybl.load(network_file, LibPowsybl.dict_to_string_string_map(parameters), StdVector{StdString}(postProcessors))
    return NetworkHandle(handle,
        LibPowsybl.id(handle),
        LibPowsybl.name(handle),
        LibPowsybl.source_format(handle),
        LibPowsybl.forecast_distance(handle),
        LibPowsybl.case_date(handle))
  end

  function save(network::NetworkHandle, network_file::String, format::String, parameters::Dict{String, String} = Dict{String, String}())
      LibPowsybl.save_network(network.handle, network_file, format, LibPowsybl.dict_to_string_string_map(parameters))
  end

  # ---------------------------------------------------------------------------
  # Network composition (merge / sub-networks / reduce)
  # ---------------------------------------------------------------------------

  # Build a NetworkHandle (with its metadata) from a raw Java handle.
  function _network_handle(handle::LibPowsybl.JavaHandle)
    return NetworkHandle(handle,
        LibPowsybl.id(handle),
        LibPowsybl.name(handle),
        LibPowsybl.source_format(handle),
        LibPowsybl.forecast_distance(handle),
        LibPowsybl.case_date(handle))
  end

  # Refresh a handle in place, so a caller keeps using the network they passed in rather
  # than being left holding the handle it had before the operation.
  function _refresh!(network::NetworkHandle, handle::LibPowsybl.JavaHandle)
    network.handle = handle
    network.id = LibPowsybl.id(handle)
    network.name = LibPowsybl.name(handle)
    network.source_format = LibPowsybl.source_format(handle)
    network.forecast_distance = LibPowsybl.forecast_distance(handle)
    network.case_date = LibPowsybl.case_date(handle)
    return network
  end

  """
      merge(network, others)
      merge(network, others::NetworkHandle...)

  Merge `others` into `network`, each becoming a sub-network of it. `network` is modified:
  it absorbs the others and afterwards refers to the merged network.
  """
  function merge(network::NetworkHandle, others::AbstractVector{<:NetworkHandle})
    list = LibPowsybl.NetworkList()
    LibPowsybl.add_network(list, network.handle)
    for other in others
      LibPowsybl.add_network(list, other.handle)
    end
    _refresh!(network, LibPowsybl.merge_networks(list))
    return nothing
  end

  merge(network::NetworkHandle, others::NetworkHandle...) = merge(network, collect(NetworkHandle, others))
  merge(network::NetworkHandle, other::NetworkHandle) = merge(network, NetworkHandle[other])

  """
      get_sub_networks(network[, all_attributes[, attributes]]) -> DataFrame

  Return the sub-networks of a (merged) network as a DataFrame.
  """
  function get_sub_networks(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.SUB_NETWORK, all_attributes, attributes)
  end

  """
      get_sub_network(network, sub_network_id::String) -> NetworkHandle

  Return the sub-network of `network` with the given id.
  """
  function get_sub_network(network::NetworkHandle, sub_network_id::String)
    return _network_handle(LibPowsybl.get_sub_network(network.handle, sub_network_id))
  end

  """
      detach(sub_network)

  Detach a sub-network from its parent into a standalone network. `sub_network` is
  modified: afterwards it refers to the detached network.
  """
  function detach(sub_network::NetworkHandle)
    _refresh!(sub_network, LibPowsybl.detach_sub_network(sub_network.handle))
    return nothing
  end

  # The engine takes every reduction criterion at once; the three functions below each
  # select one of them. `with_boundary_lines` asks for boundary lines to replace the lines
  # cut where the reduction stops.
  function _reduce(network::NetworkHandle;
                   v_min::Float64 = 0.0, v_max::Float64 = floatmax(Float64),
                   ids::Vector{String} = String[],
                   vl_depths::AbstractVector = Tuple{String, Int}[],
                   with_boundary_lines::Bool = false)
    vls = String[String(first(pair)) for pair in vl_depths]
    depths = Cint[Cint(last(pair)) for pair in vl_depths]
    LibPowsybl.reduce_network(network.handle, v_min, v_max,
                              StdVector{StdString}(ids), StdVector{StdString}(vls), StdVector{Cint}(depths),
                              with_boundary_lines)
    return nothing
  end

  """
      reduce_by_voltage_range(network, v_min, v_max; with_boundary_lines = false)

  Reduce a network in place, keeping only the voltage levels whose nominal voltage is in
  `[v_min, v_max]`.
  """
  function reduce_by_voltage_range(network::NetworkHandle, v_min::Float64, v_max::Float64;
                                   with_boundary_lines::Bool = false)
    return _reduce(network; v_min = v_min, v_max = v_max, with_boundary_lines = with_boundary_lines)
  end

  """
      reduce_by_ids(network, ids; with_boundary_lines = false)

  Reduce a network in place, keeping only the voltage levels whose id is in `ids`.
  """
  function reduce_by_ids(network::NetworkHandle, ids::Vector{String}; with_boundary_lines::Bool = false)
    return _reduce(network; ids = ids, with_boundary_lines = with_boundary_lines)
  end

  """
      reduce_by_ids_and_depths(network, vl_depths; with_boundary_lines = false)

  Reduce a network in place, keeping the given voltage levels and their neighbours up to
  the given depth. `vl_depths` is a vector of `(voltage_level_id, depth)` pairs.
  """
  function reduce_by_ids_and_depths(network::NetworkHandle, vl_depths::AbstractVector;
                                    with_boundary_lines::Bool = false)
    return _reduce(network; vl_depths = vl_depths, with_boundary_lines = with_boundary_lines)
  end

  include("NetworkCreationUtils.jl")
end
