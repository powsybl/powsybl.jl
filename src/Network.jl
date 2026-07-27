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

  function get_dangling_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.DANGLING_LINE, all_attributes, attributes)
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
  # Import / export format metadata
  # ---------------------------------------------------------------------------

  """
      get_network_import_supported_extensions() -> Vector{String}

  Return the list of file extensions (e.g. `"xiidm"`, `"uct"`, `"raw"`) that can be
  used to import a network.
  """
  function get_network_import_supported_extensions()
    return [String(extension) for extension in LibPowsybl.get_network_import_supported_extensions()]
  end

  """
      get_import_parameters(format::String) -> DataFrame

  Return, as a DataFrame, the parameters supported by a given import `format`
  (for instance `"CGMES"`, `"PSS/E"`, `"UCTE"`). Each row describes a parameter with
  its name, description, type, default value and possible values.
  """
  function get_import_parameters(format::String)
    series_array = LibPowsybl.create_importer_parameters_series_array(format)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_export_parameters(format::String) -> DataFrame

  Return, as a DataFrame, the parameters supported by a given export `format`.
  See also [`get_import_parameters`](@ref).
  """
  function get_export_parameters(format::String)
    series_array = LibPowsybl.create_exporter_parameters_series_array(format)
    return create_dataframe_from_series_array(series_array[])
  end

  # ---------------------------------------------------------------------------
  # Variant management
  # ---------------------------------------------------------------------------

  """
      get_variants_ids(network::NetworkHandle) -> Vector{String}

  Return the list of variant ids defined on the network. A network always has at
  least the initial variant.
  """
  function get_variants_ids(network::NetworkHandle)
    return [String(variant_id) for variant_id in LibPowsybl.get_variants_ids(network.handle)]
  end

  """
      get_working_variant_id(network::NetworkHandle) -> String

  Return the id of the currently active (working) variant of the network.
  """
  function get_working_variant_id(network::NetworkHandle)
    return String(LibPowsybl.get_working_variant_id(network.handle))
  end

  """
      clone_variant(network::NetworkHandle, src::String, variant::String; may_overwrite::Bool = true)

  Create a new variant `variant` by cloning the `src` variant. Cloning a variant lets
  you run several independent studies (e.g. contingencies) on the same network without
  altering the base case.
  """
  function clone_variant(network::NetworkHandle, src::String, variant::String; may_overwrite::Bool = true)
    LibPowsybl.clone_variant(network.handle, src, variant, may_overwrite)
    return nothing
  end

  """
      set_working_variant(network::NetworkHandle, variant::String)

  Set the working variant of the network. All subsequent reads and computations operate
  on this variant.
  """
  function set_working_variant(network::NetworkHandle, variant::String)
    LibPowsybl.set_working_variant(network.handle, variant)
    return nothing
  end

  """
      remove_variant(network::NetworkHandle, variant::String)

  Remove a variant from the network.
  """
  function remove_variant(network::NetworkHandle, variant::String)
    LibPowsybl.remove_variant(network.handle, variant)
    return nothing
  end

  # ---------------------------------------------------------------------------
  # Network mutation
  # ---------------------------------------------------------------------------

  """
      remove_elements(network::NetworkHandle, element_ids::Vector{String})
      remove_elements(network::NetworkHandle, element_id::String)

  Remove one or several elements from the network given their ids.
  """
  function remove_elements(network::NetworkHandle, element_ids::Vector{String})
    LibPowsybl.remove_network_elements(network.handle, StdVector{StdString}(element_ids))
    return nothing
  end

  function remove_elements(network::NetworkHandle, element_id::String)
    return remove_elements(network, [element_id])
  end

  """
      update_switch_position(network::NetworkHandle, id::String, open::Bool) -> Bool

  Open (`open = true`) or close (`open = false`) the switch identified by `id`.
  Return `true` if the switch position was actually changed.
  """
  function update_switch_position(network::NetworkHandle, id::String, open::Bool)
    return LibPowsybl.update_switch_position(network.handle, id, open)
  end

  """
      update_connectable_status(network::NetworkHandle, id::String, connected::Bool) -> Bool

  Connect (`connected = true`) or disconnect (`connected = false`) the connectable
  identified by `id` (a load, generator, line, ...). Return `true` if the status was
  actually changed.
  """
  function update_connectable_status(network::NetworkHandle, id::String, connected::Bool)
    return LibPowsybl.update_connectable_status(network.handle, id, connected)
  end

  """
      get_elements_ids(network, type; nominal_voltages, countries,
                       main_connected_component, main_synchronous_component,
                       not_connected_to_same_bus_at_both_sides) -> Vector{String}

  Return the ids of the elements of a given `type` (a `LibPowsybl.ElementType`), with
  optional filtering by nominal voltage, country and connected/synchronous component.
  """
  function get_elements_ids(network::NetworkHandle, type::LibPowsybl.ElementType;
                            nominal_voltages::Vector{Float64} = Float64[],
                            countries::Vector{String} = String[],
                            main_connected_component::Bool = true,
                            main_synchronous_component::Bool = true,
                            not_connected_to_same_bus_at_both_sides::Bool = false)
    ids = LibPowsybl.get_network_elements_ids(network.handle, type,
                                              StdVector{Float64}(nominal_voltages),
                                              StdVector{StdString}(countries),
                                              main_connected_component,
                                              main_synchronous_component,
                                              not_connected_to_same_bus_at_both_sides)
    return [String(element_id) for element_id in ids]
  end

  # ---------------------------------------------------------------------------
  # Node/breaker and bus/breaker topology views
  # ---------------------------------------------------------------------------

  """
      get_node_breaker_view_nodes(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the nodes of the node/breaker topology view of a voltage level.
  """
  function get_node_breaker_view_nodes(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_node_breaker_view_nodes(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_node_breaker_view_switches(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the switches of the node/breaker topology view of a voltage level.
  """
  function get_node_breaker_view_switches(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_node_breaker_view_switches(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_node_breaker_view_internal_connections(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the internal connections of the node/breaker topology view of a voltage level.
  """
  function get_node_breaker_view_internal_connections(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_node_breaker_view_internal_connections(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_bus_breaker_view_buses(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the buses of the bus/breaker topology view of a voltage level.
  """
  function get_bus_breaker_view_buses(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_bus_breaker_view_buses(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_bus_breaker_view_switches(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the switches of the bus/breaker topology view of a voltage level.
  """
  function get_bus_breaker_view_switches(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_bus_breaker_view_switches(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  """
      get_bus_breaker_view_elements(network::NetworkHandle, voltage_level_id::String) -> DataFrame

  Return the elements connected in the bus/breaker topology view of a voltage level.
  """
  function get_bus_breaker_view_elements(network::NetworkHandle, voltage_level_id::String)
    series_array = LibPowsybl.get_bus_breaker_view_elements(network.handle, voltage_level_id)
    return create_dataframe_from_series_array(series_array[])
  end

  include("NetworkCreationUtils.jl")
end