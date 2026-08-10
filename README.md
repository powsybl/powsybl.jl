# Powsybl.jl

Julia bindings for the [PowSyBl](https://www.powsybl.org/) framework.

PowSyBl (Power System Blocks) is an open source framework written in Java, that makes it easy to write complex software for power systems’ simulations and analysis.

PowSyBl is part of the LF Energy Foundation, a project of The Linux Foundation that supports open source innovation projects within the energy and electricity sectors.

## Installation

The Powsybl.jl package does no require any special installation. Stable releases are registered into the Julia general registry, and therefore can be deployed with the standard `Pkg` Julia package manager.

```julia
julia> using Pkg
julia> Pkg.add("Powsybl")
```

## Getting started

Some examples are available in the Test directory of this project. For the time being available features are limited to :

* Create a set of tutorial example networks such as IEEE, Eurostag and more 
* Load a network from a file, supporting CGMES, UCTE, XIIDM, BIIDM, JIIDM, Matpower, IEEE CDF, PSS/E and PowerFactory data format
* List network elements and explore their attributes through julia DataFrames

### Network exploration

From a loaded network you can have a access to the following network elements (and their attributes) :

* buses
* bus_breaker_view_buses
* generators
* loads
* batteries
* lines
* 2_windings_transformers
* 3_windings_transformers
* shunt_compensators
* non_linear_shunt_compensator_sections
* linear_shunt_compensator_sections
* boundary_lines
* tie_lines
* lcc_converter_stations
* vsc_converter_stations
* static_var_compensators
* voltage_levels
* busbar_sections
* substations
* hvdc_lines
* switches
* ratio_tap_changer_steps and phase_tap_changer_steps
* ratio_tap_changers and phase_tap_changers
* reactive_capability_curve_points
* injections
* branches
* terminals
* operational_limits (of the selected limit sets, or of every set with `show_inactive_sets = true`)
* grounds
* areas, areas_voltage_levels and areas_boundaries
* dc_lines, dc_nodes, dc_buses, dc_grounds and voltage_source_converters
* elements_properties

```julia

julia> using Powsybl

julia> network = Powsybl.Network.create_ieee9()
Powsybl.Network.NetworkHandle(Powsybl.JavaHandleAllocated(Ptr{Nothing} @0x000002bb1efac470), "ieee9cdf", "ieee9cdf", "IEEE-CDF", 0, 1.240704e9)

julia> @info Powsybl.Network.get_lines(network)
┌ Info: 6×18 DataFrame
│  Row │ id         name       r        x        g1       b1        g2       b2        p1       q1       i1       p2       q2       i2       voltage_level1_id  voltage_level2_id  bus1_id    bus2_id
│      │ StdString  StdString  Float64  Float64  Float64  Float64   Float64  Float64   Float64  Float64  Float64  Float64  Float64  Float64  StdString          StdString          StdString  StdString
│ ─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
│    1 │ L7-8-0                   0.85     7.2       0.0  0.000745      0.0  0.000745      NaN      NaN      NaN      NaN      NaN      NaN  VL2                VL8                VL2_1      VL8_0
│    2 │ L9-8-0                   1.19    10.08      0.0  0.001045      0.0  0.001045      NaN      NaN      NaN      NaN      NaN      NaN  VL3                VL8                VL3_1      VL8_0
│    3 │ L7-5-0                   3.2     16.1       0.0  0.00153       0.0  0.00153       NaN      NaN      NaN      NaN      NaN      NaN  VL2                VL5                VL2_1      VL5_0
│    4 │ L9-6-0                   3.9     17.0       0.0  0.00179       0.0  0.00179       NaN      NaN      NaN      NaN      NaN      NaN  VL3                VL6                VL3_1      VL6_0
│    5 │ L5-4-0                   1.0      8.5       0.0  0.00088       0.0  0.00088       NaN      NaN      NaN      NaN      NaN      NaN  VL5                VL1                VL5_0      VL1_1
└    6 │ L6-4-0                   1.7      9.2       0.0  0.00079       0.0  0.00079       NaN      NaN      NaN      NaN      NaN      NaN  VL6                VL1                VL6_0      VL1_1

julia>

```

### Network loading

Network are loaded from file through the Powsybl.Network.load function. Supported format are :

CGMES (all profiles in a zip archive), UCTE, XIIDM, BIIDM, JIIDM, Matpower, IEEE CDF, PSS/E and PowerFactory

```julia 
julia> Powsybl.Network.get_network_import_formats()
9-element Vector{String}:
 "BIIDM"
 "CGMES"
 "IEEE-CDF"
 "JIIDM"
 "MATPOWER"
 "POWER-FACTORY"
 "PSS/E"
 "UCTE"
 "XIIDM"
```

```julia 

julia> using Powsybl

julia> network = Powsybl.Network.load("CGMES_Full.zip")
Powsybl.Network.NetworkHandle(Powsybl.JavaHandleAllocated(Ptr{Nothing} @0x000002c926f212c0), "urn:uuid:d8ba63a9-4453-45dc-9273-a8a01ff49269", "urn:uuid:d8ba63a9-4453-45dc-9273-a8a01ff49269", "CGMES", 0, 1.612899e9)

julia> @info Powsybl.Network.get_lines(network)[:,["id", "name", "p1"]]
┌ Info: 8×3 DataFrame
│  Row │ id                                 name                   p1
│      │ StdString                          StdString              Float64
│ ─────┼──────────────────────────────────────────────────────────────────────
│    1 │ ffbabc27-1ccd-4fdc-b037-e341706c…  BE-Line_6               -52.1434
│    2 │ b58bf21a-096a-4dae-9a01-3f03b60c…  BE-Line_2              -113.252
│    3 │ df16b3dd-c905-4a6f-84ee-f067be86…  SER-RLC-1230822986      -97.2703
│    4 │ b18cd1aa-7808-49b9-a7cf-605eaf07…  BE-Line_5 + NL-Line_5   -22.4478
│    5 │ a16b4a6c-70b1-4abf-9a9d-bd0fa47f…  BE-Line_7 + NL-Line_3   -97.2713
│    6 │ 17086487-56ba-4979-b8de-064025a6…  BE-Line_1 + NL-Line_4   -79.3248
│    7 │ dad02278-bd25-476f-8f58-dbe44be7…  NL-Line_2 + BE-Line_4    16.9841
└    8 │ 78736387-5f60-4832-b3fe-d50daf81…  BE-Line_3 + NL-Line_1    -5.09077

```

Additionally, import formats may support specific parameters defined in Dict and a list of post processors in a string vector.
The list of available post processors can be accessed through a call to Powsybl.Network.get_network_available_post_processors :

````julia
Powsybl.Network.get_network_available_post_processors()
3-element Vector{String}:
 "loadflowResultsCompletion"
 "odreGeoDataImporter"
 "replaceTieLinesByLines"
````

Parameters and post processors are optional arguments of the load function : 

```julia 
julia> parameters = Dict("psse.import.ignore-base-voltage" => "true")
julia> postprocessors = ["replaceTieLinesByLines"]
julia> network = Powsybl.Network.load("network.raw", parameters, postprocessors)
```

See the [documentation](https://powsybl.readthedocs.io/projects/powsybl-core/en/v6.5.1/grid_exchange_formats/index.html) for available import parameters.
### Network export

Network can exported to a file through the Powsybl.Network.save function, taking as arguments the network, a file and an export format. 

```julia 
julia> network = Powsybl.Network.load("CGMES_Full.zip")
julia> Powsybl.Network.save(network, "Ouput.xiidm", "XIIDM")
```

The list of available export formats can be accessed :

```julia 
julia> Powsybl.Network.get_network_export_formats()
8-element Vector{String}:
 "AMPL"
 "BIIDM"
 "CGMES"
 "JIIDM"
 "MATPOWER"
 "PSS/E"
 "UCTE"
 "XIIDM"
```

Additionally, a Dict of parameters can be provided as a fourth argument to the export function

```julia 
julia> network = Powsybl.Network.load("CGMES_Full.zip")
julia> Powsybl.Network.save(network, "Ouput.xiidm", "XIIDM", Dict("iidm.export.xml.indent" => "true"))
```

See the [documentation](https://powsybl.readthedocs.io/projects/powsybl-core/en/v6.5.1/grid_exchange_formats/index.html) for available export parameters.

### Network extensions

Network extensions can be accessed through a call to Powsybl.Network.get_extensions

```julia 

julia> using Powsybl

julia> network = Powsybl.Network.create_micro_grid_be()
Powsybl.Network.NetworkHandle(Powsybl.JavaHandleAllocated(Ptr{Nothing} @0x0000000020f43260), "urn:uuid:d400c631-75a0-4c30-8aed-832b0d282e73", "urn:uuid:d400c631-75a0-4c30-8aed-832b0d282e73", "CGMES", 0, 1.4016186e9)

julia> Powsybl.Network.get_extensions(network, "activePowerControl")
2×6 DataFrame
 Row │ id                                 droop    participate  participation_factor  max_target_p  min_target_p 
     │ String                             Float64  Bool         Float64               Float64       Float64      
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 3a3b27be-b18b-4385-b557-6735d733…      NaN         true                   0.0           NaN           NaN
   2 │ 550ebe0d-f2b2-48c1-991f-cebea43a…      NaN         true                   0.0           NaN           NaN

```

Available extensions can be listed using the following call :

```julia
julia> Powsybl.Network.get_extensions_names()
19-element Vector{String}:
 "activePowerControl"
 "branchObservability"
 "busbarSectionPosition"
 "coordinatedReactiveControl"
 "detail"
 "entsoeArea"
 "entsoeCategory"
 "generatorShortCircuit"
 "hvdcAngleDroopActivePowerControl"
 "hvdcOperatorActivePowerRange"
 "identifiableShortCircuit"
 "injectionObservability"
 "linePosition"
 "measurements"
 "position"
 "secondaryVoltageControl"
 "slackTerminal"
 "standbyAutomaton"
 "substationPosition"
```

Extensions can also be created, updated and removed. As for elements, each keyword
argument is a column of the extension's dataframe (scalar or vector), coerced to the type
declared by its schema; the index column is usually the `id` of the element the extension
is attached to.

```julia
julia> network = Powsybl.Network.create_eurostag_tutorial_example1()

# Attach an activePowerControl extension to a generator
julia> Powsybl.Network.create_extensions(network, "activePowerControl";
           id = "GEN", droop = 4.0, participate = true)

julia> Powsybl.Network.get_extensions(network, "activePowerControl")

# Update it, then remove it
julia> Powsybl.Network.update_extensions(network, "activePowerControl"; id = "GEN", droop = 8.0)
julia> Powsybl.Network.remove_extensions(network, "activePowerControl", "GEN")

# Describe every available extension
julia> Powsybl.Network.get_extensions_information()
```

### Load flow module

A load flow computation can be done using the LoadFlow submodule.

#### Parameters

The most important part before running a load flow is knowing the parameters and change them if needed. Here is a list of parameters explicitly mapped:

```julia
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
      connected_component_mode::ConnectedComponentMode
      dc_power_factor::Float64
      provider_parameters::Dict{String, String}
  end
```

A default parameters set can be created : 

```julia
julia> using Powsybl
julia> parameters = Powsybl.LoadFlow.load_flow_parameters()
julia> parameters
Powsybl.LoadFlow.LoadFlowParameters(Powsybl.LoadFlow.UNIFORM_VALUES, false, true, false, false, false, true, true, true, Powsybl.LoadFlow.PROPORTIONAL_TO_GENERATION_P_MAX, true, String[], Powsybl.LoadFlow.MAIN, 1.0, Dict{String, String}())
```

All parameters are fully described in [Powsybl load flow parameters documentation](https://powsybl.readthedocs.io/projects/powsybl-core/en/stable/simulation/loadflow/configuration.html).
Some parameters are not supported by all load flow providers but specific to only one. These specific parameters could be specified in a less typed way than common parameters using the provider_parameters attribute.

#### Running a load flow

Load flow can launched in AC :

```julia
julia> using Powsybl
julia> network = Powsybl.Network.create_ieee9()
julia> parameters = Powsybl.LoadFlow.load_flow_parameters()
julia> result = Powsybl.LoadFlow.run_ac(network, parameters) 
```

or in DC :

```julia
julia> result = Powsybl.LoadFlow.run_dc(network, parameters) 
```

The result returned is a set of two dataframes, the component results and the slack bus results related to a component.

```julia
julia> result.component_results
1×7 DataFrame
 Row │ connected_component_num  synchronous_component_num  status     status_text  iteration_count  reference_bus_id  distributed_active_power 
     │ Int32                    Int32                      LoadFlow…  String       Int32            String            Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │                       0                          0  CONVERGED  Converged                  3  VL1_0                                  0.0
```

```julia
julia> result.slack_bus_results
1×4 DataFrame
 Row │ connected_component_num  synchronous_component_num  id     active_power_mismatch 
     │ Any                      Any                        Any    Any
─────┼──────────────────────────────────────────────────────────────────────────────────
   1 │ 0                        0                          VL1_0  -4.3244e-6
```

But the main output of the loadflow is actually the updated data in the network itself: all voltages and flows are now updated with the computed values.

```julia

julia> Powsybl.Network.get_buses(network)
9×7 DataFrame
 Row │ id      name    v_mag     v_angle    connected_component  synchronous_component  voltage_level_id 
     │ String  String  Float64   Float64    Int32                Int32                  String
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ VL1_0           104.0      0.0                         0                      0  VL1
   2 │ VL1_1           102.579   -2.21679                     0                      0  VL1
   3 │ VL2_0           102.5      9.28001                     0                      0  VL2
   4 │ VL2_1           102.577    3.7197                      0                      0  VL2
   5 │ VL3_0           102.5      4.66475                     0                      0  VL3
   6 │ VL3_1           103.235    1.96672                     0                      0  VL3
   7 │ VL5_0            99.5631  -3.9888                      0                      0  VL5
   8 │ VL6_0           101.265   -3.6874                      0                      0  VL6
   9 │ VL8_0           101.588    0.727537                    0                      0  VL8
````

### Creating and updating elements

Elements can be created and updated with the API: one keyword argument
per column, each value a scalar (a single element) or a vector (several elements at once).
Columns are coerced to the type declared by the element's dataframe schema, so numeric
literals work without an explicit type. The `id` column identifies the elements.

```julia
julia> using Powsybl

julia> network = Powsybl.Network.create_empty()

julia> Powsybl.Network.create_substations(network; id = "S1", country = "FR")
julia> Powsybl.Network.create_voltage_levels(network; id = "VL1", substation_id = "S1",
           topology_kind = "BUS_BREAKER", nominal_v = 400.0)
julia> Powsybl.Network.create_buses(network; id = "B1", voltage_level_id = "VL1")
julia> Powsybl.Network.create_loads(network; id = "LOAD1", voltage_level_id = "VL1",
           bus_id = "B1", p0 = 100.0, q0 = 10.0)
julia> Powsybl.Network.create_generators(network; id = "GEN1", voltage_level_id = "VL1",
           bus_id = "B1", target_p = 100.0, min_p = 0.0, max_p = 1000.0,
           target_v = 400.0, voltage_regulator_on = true)

# Update existing elements (id selects them, the other columns are the new values)
julia> Powsybl.Network.update_loads(network; id = "LOAD1", p0 = 200.0)

# Create several elements at once by passing vectors
julia> Powsybl.Network.create_buses(network; id = ["B2", "B3"], voltage_level_id = ["VL1", "VL1"])
```

Convenience creators are available for `substations`, `voltage_levels`, `buses`,
`busbar_sections`, `loads`, `generators`, `batteries`, `boundary_lines`, `lines`,
`2_windings_transformers`, `3_windings_transformers`, `switches`,
`static_var_compensators`, `lcc_converter_stations`, `vsc_converter_stations`,
`hvdc_lines`, `tie_lines`, `operational_limits`, `minmax_reactive_limits` and
`curve_reactive_limits`, `grounds`, `areas`, `areas_voltage_levels`, `areas_boundaries`,
`internal_connections`, `dc_lines`, `dc_nodes`, `dc_grounds` and
`voltage_source_converters` (plus `add_aliases`), with `update_*` helpers covering those
and the tap changers, their steps, the shunt compensator sections, `terminals`, `branches`,
`injections` and `dc_buses`. The generic `create_elements(network, element_type; kwargs...)` and
`update_elements(network, element_type; kwargs...)` cover any element type. To discover
the available columns of a dataframe, inspect an existing element table (e.g.
`Powsybl.Network.get_loads(network, true)` for all attributes).

Every creator and updater also accepts a `DataFrame` instead of keyword arguments, one row
per element, which makes a read/modify/write round trip straightforward:

```julia
julia> loads = Powsybl.Network.get_loads(network)
julia> Powsybl.Network.update_loads(network, DataFrame(id = loads[:, "id"], p0 = loads[:, "p0"] .* 2))
```

The data is given in one form or the other, never both: passing a
`DataFrame` together with keyword arguments raises an `ArgumentError`.

Some elements are described by several dataframes: a shunt compensator plus its
linear or non-linear sections, or a tap changer plus its steps. Dedicated helpers take
the extra dataframes as column sets (NamedTuples):

```julia
# Linear shunt compensator
julia> Powsybl.Network.create_shunt_compensators(network;
           id = "SHUNT", voltage_level_id = "VL1", bus_id = "B1",
           section_count = 1, model_type = "LINEAR",
           linear = (id = "SHUNT", g_per_section = 0.0, b_per_section = 1e-5, max_section_count = 1))

# Non-linear shunt compensator (one row per section)
julia> Powsybl.Network.create_shunt_compensators(network;
           id = "SHUNT2", voltage_level_id = "VL1", bus_id = "B1",
           section_count = 1, model_type = "NON_LINEAR",
           non_linear = (id = ["SHUNT2", "SHUNT2"], g = [0.0, 0.0], b = [1e-5, 2e-5]))

# Ratio tap changer with steps on a transformer
julia> Powsybl.Network.create_ratio_tap_changers(network;
           id = "TWT", tap = 1, low_tap = 0, target_v = 400.0, regulating = false,
           steps = (id = ["TWT", "TWT", "TWT"], g = [0.0, 0.0, 0.0], b = [0.0, 0.0, 0.0],
                    r = [0.0, 0.0, 0.0], x = [0.0, 0.0, 0.0], rho = [0.9, 1.0, 1.1]))
```

`create_phase_tap_changers` works the same way, with an extra `alpha` column in the
steps. Boundary lines follow the same pattern, their optional generation part being the
second dataframe:

```julia
julia> Powsybl.Network.create_boundary_lines(network;
           id = "BL1", voltage_level_id = "VL1", bus_id = "B1",
           p0 = 10.0, q0 = 3.0, r = 0.1, x = 1.0, g = 0.0, b = 0.0,
           generation = (id = "BL1", min_p = 0.0, max_p = 100.0, target_p = 50.0,
                         target_q = 10.0, target_v = 400.0, voltage_regulator_on = true))
```

The generic `create_elements(network, element_type, column_sets)` (a vector with one
column set per dataframe) covers any multi-dataframe element type, and
`create_extensions(network, extension_name, column_sets)` does the same for extensions.

Column names are checked against the dataframe schema: an unknown column, or a missing
index column, raises an `ArgumentError` rather than being forwarded to PowSyBl.
