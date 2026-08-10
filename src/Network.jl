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

  function get_boundary_lines_generation(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.BOUNDARY_LINE_GENERATION, all_attributes, attributes)
  end

  # Deprecated: dangling lines are now called boundary lines. Kept as an alias for backward
  # compatibility; use get_boundary_lines instead.
  function get_dangling_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    Base.depwarn("get_dangling_lines is deprecated, use get_boundary_lines instead.", :get_dangling_lines)
    return get_boundary_lines(network, all_attributes, attributes)
  end

  function get_dangling_lines_generation(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    Base.depwarn("get_dangling_lines_generation is deprecated, use get_boundary_lines_generation instead.",
                 :get_dangling_lines_generation)
    return get_boundary_lines_generation(network, all_attributes, attributes)
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

  function get_operational_limits(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}();
                                  show_inactive_sets::Bool = false)
    element_type = show_inactive_sets ? LibPowsybl.OPERATIONAL_LIMITS : LibPowsybl.SELECTED_OPERATIONAL_LIMITS
    return get_elements(network, element_type, all_attributes, attributes)
  end

  function get_grounds(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.GROUND, all_attributes, attributes)
  end

  function get_areas(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.AREA, all_attributes, attributes)
  end

  function get_areas_voltage_levels(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.AREA_VOLTAGE_LEVELS, all_attributes, attributes)
  end

  function get_areas_boundaries(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.AREA_BOUNDARIES, all_attributes, attributes)
  end

  function get_elements_properties(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.PROPERTIES, all_attributes, attributes)
  end

  function get_dc_lines(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.DC_LINE, all_attributes, attributes)
  end

  function get_dc_nodes(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.DC_NODE, all_attributes, attributes)
  end

  function get_dc_buses(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.DC_BUS, all_attributes, attributes)
  end

  function get_dc_grounds(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.DC_GROUND, all_attributes, attributes)
  end

  function get_voltage_source_converters(network::NetworkHandle, all_attributes::Bool = false, attributes::Vector{String} = Vector{String}())
    return get_elements(network, LibPowsybl.VOLTAGE_SOURCE_CONVERTER, all_attributes, attributes)
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

  # Series type codes returned by the metadata (match the reader in
  # create_dataframe_from_series_array): 0 = string, 1 = double, 2 = int, 3 = bool.
  function _infer_series_type(column)
    element_type = eltype(column)
    if element_type <: AbstractString
      return 0
    elseif element_type <: Bool
      return 3
    elseif element_type <: Integer
      return 2
    elseif element_type <: Real
      return 1
    else
      return 0
    end
  end

  function _fill_builder!(builder, kwargs, meta_names, meta_types, meta_indices)
    type_by_name = Dict{String, Int}()
    ordered_names = String[]
    index_names = Set{String}()
    for (name, type_code, is_index) in zip(meta_names, meta_types, meta_indices)
      column_name = String(name)
      type_by_name[column_name] = Int(type_code)
      push!(ordered_names, column_name)
      if Int(is_index) != 0
        push!(index_names, column_name)
      end
    end

    declared = !isempty(ordered_names)

    implied_index = isempty(index_names) && declared
    if implied_index
      push!(index_names, ordered_names[1])
    end

    supplied = collect(kwargs)
    provided = [entry for entry in supplied if entry.second !== nothing]

    if isempty(supplied)
      return _add_empty_index!(builder, index_names, type_by_name)
    end

    provided_names = Set(String(key) for (key, _) in provided)

    if declared
      for column_name in provided_names
        if !haskey(type_by_name, column_name)
          throw(ArgumentError("no column named \"$column_name\" for this dataframe; " *
                              "expected one of: " * join(ordered_names, ", ")))
        end
      end
    end

    if !implied_index
      for column_name in index_names
        if !(column_name in provided_names)
          throw(ArgumentError("no data provided for index column \"$column_name\""))
        end
      end
    end

    if isempty(provided)
      return _add_empty_index!(builder, index_names, type_by_name)
    end

    row_count = _column_length(first(provided).second)
    for (key, value) in provided
      size = _column_length(value)
      if size != row_count
        throw(ArgumentError("all arguments must have the same size, got size $size for " *
                            "series \"$(String(key))\", expected $row_count"))
      end
    end

    for (key, value) in provided
      column_name = String(key)
      column = value isa AbstractVector ? collect(value) : [value]
      type_code = get(type_by_name, column_name, _infer_series_type(column))
      _add_series!(builder, column_name, column_name in index_names, type_code, column)
    end
    return builder
  end

  _column_length(value) = value isa AbstractVector ? length(value) : 1

  function _add_empty_index!(builder, index_names, type_by_name)
    for name in index_names
      _add_series!(builder, name, true, get(type_by_name, name, 0), Int[])
    end
    return builder
  end

  function _add_series!(builder, name, is_index, type_code, column)
    if type_code == 0
      LibPowsybl.add_string_series(builder, name, is_index, StdVector{StdString}(String.(column)))
    elseif type_code == 1
      LibPowsybl.add_double_series(builder, name, is_index, StdVector{Float64}(Float64.(column)))
    elseif type_code == 2
      LibPowsybl.add_int_series(builder, name, is_index, StdVector{Cint}(Cint.(column)))
    elseif type_code == 3
      LibPowsybl.add_bool_series(builder, name, is_index, StdVector{Cint}(Cint.(Bool.(column))))
    end
    return builder
  end

  _column_pairs(columns::DataFrame) = [Symbol(name) => columns[!, name] for name in names(columns)]
  _column_pairs(columns) = pairs(columns)

  function _reject_mixed_input(kwargs)
    if !isempty(kwargs)
      throw(ArgumentError("provide the data in only one form: a DataFrame or keyword arguments"))
    end
    return nothing
  end

  """
      create_elements(network, element_type; kwargs...)

  Create network elements of the given `element_type` (a `LibPowsybl.ElementType`).
  Each keyword argument is a column of the creation dataframe; a value may be a scalar (one
  element) or a vector (several at once), and all the arguments of one call must have the
  same number of values. An argument left at `nothing` counts as not given. This is the
  generic entry point behind the `create_*` helpers below.
  """
  function create_elements(network::NetworkHandle, element_type::LibPowsybl.ElementType; kwargs...)
    return create_elements(network, element_type, Any[kwargs])
  end

  """
      create_elements(network, element_type, df::DataFrame)

  Create network elements from a `DataFrame`, one row per element and one column per attribute
  """
  function create_elements(network::NetworkHandle, element_type::LibPowsybl.ElementType, df::DataFrame; kwargs...)
    _reject_mixed_input(kwargs)
    return create_elements(network, element_type, Any[df])
  end

  """
      update_elements(network, element_type, df::DataFrame)

  Update network elements from a `DataFrame`. The index column (usually `id`) selects the
  elements, the other columns are the values to set.
  """
  function update_elements(network::NetworkHandle, element_type::LibPowsybl.ElementType, df::DataFrame; kwargs...)
    _reject_mixed_input(kwargs)
    return update_elements(network, element_type; _column_pairs(df)...)
  end

  """
      update_elements(network, element_type; kwargs...)

  Update existing network elements of the given `element_type`. The `id` column selects
  the elements; the other keyword columns are the values to set.
  """
  function update_elements(network::NetworkHandle, element_type::LibPowsybl.ElementType; kwargs...)
    builder = LibPowsybl.ElementDataframe()
    _fill_builder!(builder, kwargs,
                   LibPowsybl.get_element_metadata_names(element_type),
                   LibPowsybl.get_element_metadata_types(element_type),
                   LibPowsybl.get_element_metadata_indices(element_type))
    LibPowsybl.update_element(network.handle, builder, element_type, per_unit, nominal_apparent_power)
    return nothing
  end

  """
      create_elements(network, element_type, column_sets::AbstractVector)

  Create elements that need several dataframes (shunt compensators with their
  linear/non-linear sections, tap changers with their steps). `column_sets` holds one
  column set (a NamedTuple, `Dict`, or the pairs of a keyword list) per dataframe, in the
  order given by the creation schema. Trailing dataframes may be omitted and any dataframe
  may be left empty (`(;)`).
  """
  function create_elements(network::NetworkHandle, element_type::LibPowsybl.ElementType, column_sets::AbstractVector)
    builder = LibPowsybl.ElementDataframe()
    # Fall back to a single dataframe when the schema is unavailable, so the provided
    # columns are still sent rather than silently dropped.
    dataframe_count = max(Int(LibPowsybl.get_element_creation_dataframes_count(element_type)), 1)
    for i in 0:(dataframe_count - 1)
      columns = (i + 1) <= length(column_sets) ? column_sets[i + 1] : (;)
      _fill_builder!(builder, _column_pairs(columns),
                     LibPowsybl.get_element_creation_metadata_names_at(element_type, i),
                     LibPowsybl.get_element_creation_metadata_types_at(element_type, i),
                     LibPowsybl.get_element_creation_metadata_indices_at(element_type, i))
      LibPowsybl.finish_dataframe(builder)
    end
    LibPowsybl.create_element(network.handle, builder, element_type)
    return nothing
  end

  """
      create_shunt_compensators(network; linear = nothing, non_linear = nothing, kwargs...)

  Create shunt compensators. The keyword arguments describe the shunt compensators
  themselves; the sections are given either as a `linear` model
  (`g_per_section`, `b_per_section`, `max_section_count`) or as a `non_linear` set of
  sections (`g`, `b`, one row per section). Both `linear` and `non_linear` are column
  sets (NamedTuples) whose `id` links back to the shunt.
  """
  function create_shunt_compensators(network::NetworkHandle; linear = nothing, non_linear = nothing, kwargs...)
    return create_elements(network, LibPowsybl.SHUNT_COMPENSATOR,
                           Any[kwargs,
                               linear === nothing ? (;) : linear,
                               non_linear === nothing ? (;) : non_linear])
  end

  function create_shunt_compensators(network::NetworkHandle, df::DataFrame; linear = nothing, non_linear = nothing)
    return create_elements(network, LibPowsybl.SHUNT_COMPENSATOR,
                           Any[df,
                               linear === nothing ? (;) : linear,
                               non_linear === nothing ? (;) : non_linear])
  end

  """
      create_ratio_tap_changers(network; steps, kwargs...)

  Create ratio tap changers. The keyword arguments describe the tap changers (their `id`
  is the transformer they are added to); `steps` is a column set with one row per step
  (`r`, `x`, `g`, `b`, `rho`).
  """
  function create_ratio_tap_changers(network::NetworkHandle; steps, kwargs...)
    return create_elements(network, LibPowsybl.RATIO_TAP_CHANGER, Any[kwargs, steps])
  end

  function create_ratio_tap_changers(network::NetworkHandle, df::DataFrame; steps)
    return create_elements(network, LibPowsybl.RATIO_TAP_CHANGER, Any[df, steps])
  end

  """
      create_phase_tap_changers(network; steps, kwargs...)

  Create phase tap changers. Like [`create_ratio_tap_changers`](@ref), but the `steps`
  additionally carry an `alpha` (phase shift) column.
  """
  function create_phase_tap_changers(network::NetworkHandle; steps, kwargs...)
    return create_elements(network, LibPowsybl.PHASE_TAP_CHANGER, Any[kwargs, steps])
  end

  function create_phase_tap_changers(network::NetworkHandle, df::DataFrame; steps)
    return create_elements(network, LibPowsybl.PHASE_TAP_CHANGER, Any[df, steps])
  end

  """
      create_boundary_lines(network; generation = nothing, kwargs...)

  Create boundary lines. The keyword arguments describe the boundary lines themselves;
  `generation` is an optional column set describing their generation part
  (`min_p`, `max_p`, `target_p`, `target_q`, `target_v`, `voltage_regulator_on`), whose
  `id` links back to the boundary line.
  """
  function create_boundary_lines(network::NetworkHandle; generation = nothing, kwargs...)
    return create_elements(network, LibPowsybl.BOUNDARY_LINE,
                           Any[kwargs, generation === nothing ? (;) : generation])
  end

  function create_boundary_lines(network::NetworkHandle, df::DataFrame; generation = nothing)
    return create_elements(network, LibPowsybl.BOUNDARY_LINE,
                           Any[df, generation === nothing ? (;) : generation])
  end

  # Convenience creators and updaters, one per single-dataframe element type.
  # Each entry generates both a keyword method and a DataFrame method.
  const _CREATORS = [
    ("substations", :SUBSTATION),
    ("voltage_levels", :VOLTAGE_LEVEL),
    ("buses", :BUS),
    ("busbar_sections", :BUSBAR_SECTION),
    ("loads", :LOAD),
    ("generators", :GENERATOR),
    ("batteries", :BATTERY),
    ("lines", :LINE),
    ("2_windings_transformers", :TWO_WINDINGS_TRANSFORMER),
    ("3_windings_transformers", :THREE_WINDINGS_TRANSFORMER),
    ("switches", :SWITCH),
    ("static_var_compensators", :STATIC_VAR_COMPENSATOR),
    ("lcc_converter_stations", :LCC_CONVERTER_STATION),
    ("vsc_converter_stations", :VSC_CONVERTER_STATION),
    ("hvdc_lines", :HVDC_LINE),
    ("tie_lines", :TIE_LINE),
    ("operational_limits", :OPERATIONAL_LIMITS),
    ("minmax_reactive_limits", :MINMAX_REACTIVE_LIMITS),
    ("curve_reactive_limits", :REACTIVE_CAPABILITY_CURVE_POINT),
    ("grounds", :GROUND),
    ("areas", :AREA),
    ("areas_voltage_levels", :AREA_VOLTAGE_LEVELS),
    ("areas_boundaries", :AREA_BOUNDARIES),
    ("internal_connections", :INTERNAL_CONNECTION),
    ("dc_lines", :DC_LINE),
    ("dc_nodes", :DC_NODE),
    ("dc_grounds", :DC_GROUND),
    ("voltage_source_converters", :VOLTAGE_SOURCE_CONVERTER),
  ]

  const _UPDATERS = [
    ("substations", :SUBSTATION),
    ("voltage_levels", :VOLTAGE_LEVEL),
    ("buses", :BUS),
    ("busbar_sections", :BUSBAR_SECTION),
    ("loads", :LOAD),
    ("generators", :GENERATOR),
    ("batteries", :BATTERY),
    ("boundary_lines", :BOUNDARY_LINE),
    ("boundary_lines_generation", :BOUNDARY_LINE_GENERATION),
    ("lines", :LINE),
    ("2_windings_transformers", :TWO_WINDINGS_TRANSFORMER),
    ("3_windings_transformers", :THREE_WINDINGS_TRANSFORMER),
    ("switches", :SWITCH),
    ("shunt_compensators", :SHUNT_COMPENSATOR),
    ("linear_shunt_compensator_sections", :LINEAR_SHUNT_COMPENSATOR_SECTION),
    ("non_linear_shunt_compensator_sections", :NON_LINEAR_SHUNT_COMPENSATOR_SECTION),
    ("static_var_compensators", :STATIC_VAR_COMPENSATOR),
    ("vsc_converter_stations", :VSC_CONVERTER_STATION),
    ("lcc_converter_stations", :LCC_CONVERTER_STATION),
    ("hvdc_lines", :HVDC_LINE),
    ("tie_lines", :TIE_LINE),
    ("ratio_tap_changers", :RATIO_TAP_CHANGER),
    ("ratio_tap_changer_steps", :RATIO_TAP_CHANGER_STEP),
    ("phase_tap_changers", :PHASE_TAP_CHANGER),
    ("phase_tap_changer_steps", :PHASE_TAP_CHANGER_STEP),
    ("operational_limits", :OPERATIONAL_LIMITS),
    ("terminals", :TERMINAL),
    ("branches", :BRANCH),
    ("injections", :INJECTION),
    ("grounds", :GROUND),
    ("areas", :AREA),
    ("dc_lines", :DC_LINE),
    ("dc_nodes", :DC_NODE),
    ("dc_buses", :DC_BUS),
    ("dc_grounds", :DC_GROUND),
    ("voltage_source_converters", :VOLTAGE_SOURCE_CONVERTER),
  ]

  for (suffix, element_type) in _CREATORS
    name = Symbol("create_", suffix)
    @eval begin
      $name(network::NetworkHandle; kwargs...) = create_elements(network, LibPowsybl.$element_type; kwargs...)
      $name(network::NetworkHandle, df::DataFrame; kwargs...) = create_elements(network, LibPowsybl.$element_type, df; kwargs...)
    end
  end

  for (suffix, element_type) in _UPDATERS
    name = Symbol("update_", suffix)
    @eval begin
      $name(network::NetworkHandle; kwargs...) = update_elements(network, LibPowsybl.$element_type; kwargs...)
      $name(network::NetworkHandle, df::DataFrame; kwargs...) = update_elements(network, LibPowsybl.$element_type, df; kwargs...)
    end
  end

  add_aliases(network::NetworkHandle; kwargs...) = create_elements(network, LibPowsybl.ALIAS; kwargs...)
  add_aliases(network::NetworkHandle, df::DataFrame; kwargs...) = create_elements(network, LibPowsybl.ALIAS, df; kwargs...)

  # Kept as aliases for backward compatibility; use the boundary line versions instead.
  function create_dangling_lines(network::NetworkHandle; generation = nothing, kwargs...)
    Base.depwarn("create_dangling_lines is deprecated, use create_boundary_lines instead.", :create_dangling_lines)
    return create_boundary_lines(network; generation = generation, kwargs...)
  end

  function update_dangling_lines(network::NetworkHandle; kwargs...)
    Base.depwarn("update_dangling_lines is deprecated, use update_boundary_lines instead.", :update_dangling_lines)
    return update_boundary_lines(network; kwargs...)
  end

  function update_dangling_lines_generation(network::NetworkHandle; kwargs...)
    Base.depwarn("update_dangling_lines_generation is deprecated, use update_boundary_lines_generation instead.",
                 :update_dangling_lines_generation)
    return update_boundary_lines_generation(network; kwargs...)
  end

  # Extension creation, update and removal
  """
      get_extensions_information() -> DataFrame

  Return a DataFrame describing all the extensions supported by the underlying PowSyBl
  installation (name, attributes, ...).
  """
  function get_extensions_information()
    series_array = LibPowsybl.get_extensions_information()
    return create_dataframe_from_series_array(series_array[])
  end

  """
      create_extensions(network, extension_name; kwargs...)

  Create extensions of type `extension_name` (e.g. `"activePowerControl"`). Each keyword
  argument is a column of the extension's creation dataframe; the index column is usually
  `id` (the element the extension is attached to). See [`get_extensions_names`](@ref) for
  the available extension types.
  """
  function create_extensions(network::NetworkHandle, extension_name::String; kwargs...)
    # Goes through the multi-dataframe path so that an extension whose schema declares
    # several dataframes still gets them all, the trailing ones empty.
    return create_extensions(network, extension_name, Any[kwargs])
  end

  """
      create_extensions(network, extension_name, column_sets::AbstractVector)

  Create extensions that need several dataframes. `column_sets` holds one column set (a
  NamedTuple, `Dict`, or the pairs of a keyword list) per dataframe, in the order given by
  the extension's creation schema. Trailing dataframes may be omitted and any dataframe may
  be left empty (`(;)`). A `DataFrame` may be used for any of the column
  sets, and a lone `DataFrame` may be passed instead of the vector.
  """
  function create_extensions(network::NetworkHandle, extension_name::String, column_sets::AbstractVector)
    builder = LibPowsybl.ElementDataframe()
    dataframe_count = max(Int(LibPowsybl.get_extension_creation_dataframes_count(extension_name)), 1)
    for i in 0:(dataframe_count - 1)
      columns = (i + 1) <= length(column_sets) ? column_sets[i + 1] : (;)
      _fill_builder!(builder, _column_pairs(columns),
                     LibPowsybl.get_extension_creation_metadata_names_at(extension_name, i),
                     LibPowsybl.get_extension_creation_metadata_types_at(extension_name, i),
                     LibPowsybl.get_extension_creation_metadata_indices_at(extension_name, i))
      LibPowsybl.finish_dataframe(builder)
    end
    LibPowsybl.create_extensions(network.handle, builder, extension_name)
    return nothing
  end

  """
      update_extensions(network, extension_name; table_name = "", kwargs...)

  Update existing extensions of type `extension_name`. Some extensions expose several
  tables (e.g. a main table and a secondary one); `table_name` selects which one to
  update (empty for the default table).
  """
  function create_extensions(network::NetworkHandle, extension_name::String, df::DataFrame; kwargs...)
    _reject_mixed_input(kwargs)
    return create_extensions(network, extension_name, Any[df])
  end

  """
      update_extensions(network, extension_name, df::DataFrame; table_name = "")

  Update existing extensions from a `DataFrame` instead of named arguments.
  """
  function update_extensions(network::NetworkHandle, extension_name::String, df::DataFrame;
                             table_name::String = "", kwargs...)
    _reject_mixed_input(kwargs)
    return update_extensions(network, extension_name; table_name = table_name, _column_pairs(df)...)
  end

  function update_extensions(network::NetworkHandle, extension_name::String; table_name::String = "", kwargs...)
    builder = LibPowsybl.ElementDataframe()
    _fill_builder!(builder, kwargs,
                   LibPowsybl.get_extension_metadata_names(extension_name, table_name),
                   LibPowsybl.get_extension_metadata_types(extension_name, table_name),
                   LibPowsybl.get_extension_metadata_indices(extension_name, table_name))
    LibPowsybl.update_extension(network.handle, builder, extension_name, table_name)
    return nothing
  end

  """
      remove_extensions(network, extension_name, ids)
      remove_extensions(network, extension_name, id)

  Remove the extensions of type `extension_name` from the elements with the given ids.
  """
  function remove_extensions(network::NetworkHandle, extension_name::String, ids::Vector{String})
    LibPowsybl.remove_extensions(network.handle, extension_name, StdVector{StdString}(ids))
    return nothing
  end

  function remove_extensions(network::NetworkHandle, extension_name::String, id::String)
    return remove_extensions(network, extension_name, [id])
  end

  include("NetworkCreationUtils.jl")
end
