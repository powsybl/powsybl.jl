# Copyright (c) 2026, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Diagram
  using ..LibPowsybl
  using ..Network
  using CxxWrap
  using DataFrames

  # ---------------------------------------------------------------------------
  # Diagram parameters
  # ---------------------------------------------------------------------------

  """
  How a network area diagram is laid out.
  """
  @enum NadLayoutType begin
    FORCE_LAYOUT = LibPowsybl.NAD_LAYOUT_FORCE_LAYOUT
    GEOGRAPHICAL = LibPowsybl.NAD_LAYOUT_GEOGRAPHICAL
  end

  """
  What an edge of a network area diagram is labelled with.
  """
  @enum EdgeInfoType begin
    ACTIVE_POWER = LibPowsybl.EDGE_INFO_ACTIVE_POWER
    REACTIVE_POWER = LibPowsybl.EDGE_INFO_REACTIVE_POWER
    CURRENT = LibPowsybl.EDGE_INFO_CURRENT
    NAME = LibPowsybl.EDGE_INFO_NAME
    VALUE_PERMANENT_LIMIT_PERCENTAGE = LibPowsybl.EDGE_INFO_VALUE_PERMANENT_LIMIT_PERCENTAGE
    EMPTY = LibPowsybl.EDGE_INFO_EMPTY
  end

  """
  What each of the four labels on a network area diagram edge carries.
  """
  mutable struct EdgeInfoParameters
    info_side_external::EdgeInfoType
    info_middle_side1::EdgeInfoType
    info_middle_side2::EdgeInfoType
    info_side_internal::EdgeInfoType
  end

  EdgeInfoParameters(; info_side_external::EdgeInfoType = ACTIVE_POWER,
                       info_middle_side1::EdgeInfoType = EMPTY,
                       info_middle_side2::EdgeInfoType = EMPTY,
                       info_side_internal::EdgeInfoType = EMPTY) =
    EdgeInfoParameters(info_side_external, info_middle_side1, info_middle_side2, info_side_internal)

  """
  Parameters of a single line diagram. `component_library` names one of the libraries
  [`get_single_line_diagram_component_library_names`](@ref) reports.
  """
  mutable struct SldParameters
    use_name::Bool
    center_name::Bool
    diagonal_label::Bool
    nodes_infos::Bool
    tooltip_enabled::Bool
    topological_coloring::Bool
    component_library::String
    display_current_feeder_info::Bool
    active_power_unit::String
    reactive_power_unit::String
    current_unit::String
  end

  SldParameters(; use_name::Bool = false, center_name::Bool = false, diagonal_label::Bool = false,
                  nodes_infos::Bool = false, tooltip_enabled::Bool = false,
                  topological_coloring::Bool = true, component_library::AbstractString = "Convergence",
                  display_current_feeder_info::Bool = false, active_power_unit::AbstractString = "",
                  reactive_power_unit::AbstractString = "", current_unit::AbstractString = "") =
    SldParameters(use_name, center_name, diagonal_label, nodes_infos, tooltip_enabled,
                  topological_coloring, String(component_library), display_current_feeder_info,
                  String(active_power_unit), String(reactive_power_unit), String(current_unit))

  """
  Parameters of a network area diagram.
  """
  mutable struct NadParameters
    edge_info_along_edge::Bool
    id_displayed::Bool
    power_value_precision::Int
    angle_value_precision::Int
    current_value_precision::Int
    voltage_value_precision::Int
    bus_legend::Bool
    substation_description_displayed::Bool
    layout_type::NadLayoutType
    scaling_factor::Int
    radius_factor::Float64
    voltage_level_details::Bool
    injections_added::Bool
    edge_info_parameters::EdgeInfoParameters
    scale_factor::Float64
    timeout_seconds::Float64
    edge_info_included::Bool
    voltage_level_legends_included::Bool
  end

  NadParameters(; edge_info_along_edge::Bool = true, id_displayed::Bool = false,
                  power_value_precision::Integer = 0, angle_value_precision::Integer = 1,
                  current_value_precision::Integer = 0, voltage_value_precision::Integer = 1,
                  bus_legend::Bool = true, substation_description_displayed::Bool = false,
                  layout_type::NadLayoutType = FORCE_LAYOUT, scaling_factor::Integer = 150000,
                  radius_factor::Real = 150.0, voltage_level_details::Bool = true,
                  injections_added::Bool = false,
                  edge_info_parameters::EdgeInfoParameters = EdgeInfoParameters(),
                  scale_factor::Real = 1.0, timeout_seconds::Real = 10.0,
                  edge_info_included::Bool = true, voltage_level_legends_included::Bool = true) =
    NadParameters(edge_info_along_edge, id_displayed, Int(power_value_precision),
                  Int(angle_value_precision), Int(current_value_precision),
                  Int(voltage_value_precision), bus_legend, substation_description_displayed,
                  layout_type, Int(scaling_factor), Float64(radius_factor), voltage_level_details,
                  injections_added, edge_info_parameters, Float64(scale_factor),
                  Float64(timeout_seconds), edge_info_included, voltage_level_legends_included)

  # The engine defaults are the starting point, so any field this struct does not carry
  # keeps the value the engine chose rather than an uninitialised one.
  function _to_c(parameters::SldParameters)
    c = LibPowsybl.default_sld_parameters()
    LibPowsybl.use_name(c, parameters.use_name)
    LibPowsybl.center_name(c, parameters.center_name)
    LibPowsybl.diagonal_label(c, parameters.diagonal_label)
    LibPowsybl.nodes_infos(c, parameters.nodes_infos)
    LibPowsybl.tooltip_enabled(c, parameters.tooltip_enabled)
    LibPowsybl.topological_coloring(c, parameters.topological_coloring)
    LibPowsybl.component_library(c, parameters.component_library)
    LibPowsybl.display_current_feeder_info(c, parameters.display_current_feeder_info)
    LibPowsybl.active_power_unit(c, parameters.active_power_unit)
    LibPowsybl.reactive_power_unit(c, parameters.reactive_power_unit)
    LibPowsybl.current_unit(c, parameters.current_unit)
    return c
  end

  function _to_c(parameters::NadParameters)
    c = LibPowsybl.default_nad_parameters()
    LibPowsybl.edge_info_along_edge(c, parameters.edge_info_along_edge)
    LibPowsybl.id_displayed(c, parameters.id_displayed)
    LibPowsybl.power_value_precision(c, Int32(parameters.power_value_precision))
    LibPowsybl.angle_value_precision(c, Int32(parameters.angle_value_precision))
    LibPowsybl.current_value_precision(c, Int32(parameters.current_value_precision))
    LibPowsybl.voltage_value_precision(c, Int32(parameters.voltage_value_precision))
    LibPowsybl.bus_legend(c, parameters.bus_legend)
    LibPowsybl.substation_description_displayed(c, parameters.substation_description_displayed)
    LibPowsybl.layout_type(c, LibPowsybl.NadLayoutType(parameters.layout_type))
    LibPowsybl.scaling_factor(c, Int32(parameters.scaling_factor))
    LibPowsybl.radius_factor(c, parameters.radius_factor)
    LibPowsybl.voltage_level_details(c, parameters.voltage_level_details)
    LibPowsybl.injections_added(c, parameters.injections_added)
    LibPowsybl.info_side_external(c, LibPowsybl.EdgeInfoType(parameters.edge_info_parameters.info_side_external))
    LibPowsybl.info_middle_side1(c, LibPowsybl.EdgeInfoType(parameters.edge_info_parameters.info_middle_side1))
    LibPowsybl.info_middle_side2(c, LibPowsybl.EdgeInfoType(parameters.edge_info_parameters.info_middle_side2))
    LibPowsybl.info_side_internal(c, LibPowsybl.EdgeInfoType(parameters.edge_info_parameters.info_side_internal))
    LibPowsybl.scale_factor(c, parameters.scale_factor)
    LibPowsybl.timeout_seconds(c, parameters.timeout_seconds)
    LibPowsybl.edge_info_included(c, parameters.edge_info_included)
    LibPowsybl.voltage_level_legends_included(c, parameters.voltage_level_legends_included)
    return c
  end

  # ---------------------------------------------------------------------------
  # Single line diagram (SLD)
  # ---------------------------------------------------------------------------

  """
  A rendered diagram: the SVG itself, and the metadata describing what it contains, which
  is `nothing` when the diagram was produced without any.

  Printing an `Svg` prints the SVG, and it renders directly in environments that display
  `image/svg+xml`.
  """
  struct Svg
    svg::String
    metadata::Union{String, Nothing}
  end

  Base.show(io::IO, diagram::Svg) = print(io, diagram.svg)
  Base.show(io::IO, ::MIME"image/svg+xml", diagram::Svg) = print(io, diagram.svg)

  # The engine returns the SVG and its metadata as two strings.
  function _svg(svg_and_metadata)
    parts = [String(part) for part in svg_and_metadata]
    return Svg(parts[1], length(parts) > 1 && !isempty(parts[2]) ? parts[2] : nothing)
  end

  """
      get_single_line_diagram(network, container_id; parameters = SldParameters()) -> Svg

  Return the single line diagram of a voltage level or substation (identified by
  `container_id`), as the SVG and the metadata describing it.
  """
  function get_single_line_diagram(network::Network.NetworkHandle, container_id::String;
                                   parameters::SldParameters = SldParameters())
    return _svg(LibPowsybl.get_single_line_diagram_svg_and_metadata(network.handle, container_id,
                                                                   _to_c(parameters)))
  end

  """
      write_single_line_diagram_svg(network, container_id, svg_file; metadata_file = "",
                                    parameters = SldParameters())

  Write the single line diagram of a voltage level or substation to `svg_file`.
  When `metadata_file` is non-empty, the diagram metadata is written there too.
  """
  function write_single_line_diagram_svg(network::Network.NetworkHandle, container_id::String, svg_file::String;
                                         metadata_file::String = "",
                                         parameters::SldParameters = SldParameters())
    LibPowsybl.write_single_line_diagram_svg(network.handle, container_id, svg_file, metadata_file,
                                             _to_c(parameters))
    return nothing
  end

  """
      get_single_line_diagram_component_library_names() -> Vector{String}

  Return the names of the available single line diagram component libraries.
  """
  function get_single_line_diagram_component_library_names()
    return [String(name) for name in LibPowsybl.get_single_line_diagram_component_library_names()]
  end

  """
      get_matrix_multi_substation_single_line_diagram(network, matrix_ids; parameters = SldParameters()) -> Svg

  Return one diagram holding several substations, laid out as the matrix `matrix_ids`
  describes: one entry per row, each listing the substation ids of that row.
  """
  function get_matrix_multi_substation_single_line_diagram(network::Network.NetworkHandle,
                                                           matrix_ids::AbstractVector;
                                                           parameters::SldParameters = SldParameters())
    ids, row_lengths = _flatten_matrix(matrix_ids)
    return _svg(LibPowsybl.get_matrix_multi_substation_svg_and_metadata(network.handle, ids, row_lengths,
                                                                       _to_c(parameters)))
  end

  """
      write_matrix_multi_substation_single_line_diagram_svg(network, matrix_ids, svg_file;
                                                           metadata_file = "", parameters = SldParameters())

  Write the diagram of several substations, laid out as `matrix_ids` describes, to `svg_file`.
  """
  function write_matrix_multi_substation_single_line_diagram_svg(network::Network.NetworkHandle,
                                                                 matrix_ids::AbstractVector, svg_file::String;
                                                                 metadata_file::String = "",
                                                                 parameters::SldParameters = SldParameters())
    ids, row_lengths = _flatten_matrix(matrix_ids)
    LibPowsybl.write_matrix_multi_substation_single_line_diagram_svg(network.handle, ids, row_lengths,
                                                                     svg_file, metadata_file, _to_c(parameters))
    return nothing
  end

  # A single id stands for a list of one, as it does upstream.
  _as_id_vector(ids::AbstractString) = [String(ids)]
  _as_id_vector(ids) = String.(collect(ids))

  # The engine takes the matrix as its ids and the length of each row.
  function _flatten_matrix(matrix_ids::AbstractVector)
    ids = String[]
    row_lengths = Cint[]
    for row in matrix_ids
      row_ids = _as_id_vector(row)
      append!(ids, row_ids)
      push!(row_lengths, Cint(length(row_ids)))
    end
    return StdVector{StdString}(ids), StdVector{Cint}(row_lengths)
  end

  # ---------------------------------------------------------------------------
  # Network area diagram (NAD)
  # ---------------------------------------------------------------------------

  """
      get_network_area_diagram(network; voltage_level_ids = String[], depth = 0,
                               high_nominal_voltage_bound = -1.0,
                               low_nominal_voltage_bound = -1.0,
                               parameters = NadParameters()) -> Svg

  Return the network area diagram, as the SVG and the metadata describing it. With an
  empty `voltage_level_ids`
  the whole network is drawn; otherwise the diagram is centered on the given voltage
  levels and expanded by `depth` hops; a single id may be given on its own. The nominal
  voltage bounds (`-1.0` meaning no
  bound) filter the displayed voltage levels.
  """
  function get_network_area_diagram(network::Network.NetworkHandle;
                                        voltage_level_ids::Union{AbstractString, AbstractVector} = String[],
                                        depth::Integer = 0,
                                        high_nominal_voltage_bound::Float64 = -1.0,
                                        low_nominal_voltage_bound::Float64 = -1.0,
                                        parameters::NadParameters = NadParameters())
    return _svg(LibPowsybl.get_network_area_diagram_svg_and_metadata(network.handle,
                                                                     StdVector{StdString}(_as_id_vector(voltage_level_ids)),
                                                                     Int32(depth),
                                                                     high_nominal_voltage_bound,
                                                                     low_nominal_voltage_bound,
                                                                     _to_c(parameters)))
  end

  """
      write_network_area_diagram(network, svg_file; voltage_level_ids = String[],
                                     depth = 0, high_nominal_voltage_bound = -1.0,
                                     low_nominal_voltage_bound = -1.0, metadata_file = "",
                                     parameters = NadParameters())

  Write the network area diagram to `svg_file`. See [`get_network_area_diagram`](@ref)
  for the meaning of the arguments.
  """
  function write_network_area_diagram(network::Network.NetworkHandle, svg_file::String;
                                          voltage_level_ids::Union{AbstractString, AbstractVector} = String[],
                                          depth::Integer = 0,
                                          high_nominal_voltage_bound::Float64 = -1.0,
                                          low_nominal_voltage_bound::Float64 = -1.0,
                                          metadata_file::String = "",
                                          parameters::NadParameters = NadParameters())
    LibPowsybl.write_network_area_diagram_svg(network.handle, svg_file, metadata_file,
                                              StdVector{StdString}(_as_id_vector(voltage_level_ids)),
                                              Int32(depth),
                                              high_nominal_voltage_bound,
                                              low_nominal_voltage_bound,
                                              _to_c(parameters))
    return nothing
  end

  """
      get_network_area_diagram_displayed_voltage_levels(network, voltage_level_ids, depth = 0) -> Vector{String}

  Return the ids of the voltage levels that would be displayed in a network area diagram
  centered on `voltage_level_ids`, a single id or several, and expanded by `depth` hops.
  """
  function get_network_area_diagram_displayed_voltage_levels(network::Network.NetworkHandle,
                                                             voltage_level_ids::Union{AbstractString, AbstractVector},
                                                             depth::Integer = 0)
    return [String(vl_id) for vl_id in LibPowsybl.get_network_area_diagram_displayed_voltage_levels(network.handle,
                                                                                                    StdVector{StdString}(_as_id_vector(voltage_level_ids)),
                                                                                                    Int32(depth))]
  end

  """
  The labels and styles a network area diagram draws, each a `DataFrame` or `nothing`.
  [`get_default_nad_profile`](@ref) fills in the five the engine can describe by itself.
  """
  struct NadProfile
    branch_labels::Union{DataFrame, Nothing}
    three_wt_labels::Union{DataFrame, Nothing}
    injections_labels::Union{DataFrame, Nothing}
    bus_descriptions::Union{DataFrame, Nothing}
    vl_descriptions::Union{DataFrame, Nothing}
    bus_node_styles::Union{DataFrame, Nothing}
    edge_styles::Union{DataFrame, Nothing}
    three_wt_styles::Union{DataFrame, Nothing}
  end

  NadProfile(; branch_labels = nothing, three_wt_labels = nothing, injections_labels = nothing,
               bus_descriptions = nothing, vl_descriptions = nothing, bus_node_styles = nothing,
               edge_styles = nothing, three_wt_styles = nothing) =
    NadProfile(branch_labels, three_wt_labels, injections_labels, bus_descriptions,
               vl_descriptions, bus_node_styles, edge_styles, three_wt_styles)

  """
      get_default_nad_profile(network) -> NadProfile

  Return the labels and descriptions a network area diagram of `network` would use by
  default, as a [`NadProfile`](@ref) whose five label and description tables are filled in
  and whose style tables are `nothing`.
  """
  function get_default_nad_profile(network::Network.NetworkHandle)
    table(series_array) = Network.create_dataframe_from_series_array(series_array[])
    return NadProfile(
      branch_labels = table(LibPowsybl.get_default_branch_labels_nad(network.handle)),
      three_wt_labels = table(LibPowsybl.get_default_twt_labels_nad(network.handle)),
      injections_labels = table(LibPowsybl.get_default_injections_labels_nad(network.handle)),
      bus_descriptions = table(LibPowsybl.get_default_bus_descriptions_nad(network.handle)),
      vl_descriptions = table(LibPowsybl.get_default_voltage_level_descriptions_nad(network.handle)))
  end
end
