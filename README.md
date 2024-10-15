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
* batteries
* lines
* 2_windings_transformers
* 3_windings_transformers
* shunt_compensators
* non_linear_shunt_compensator_sections
* linear_shunt_compensator_sections
* dangling_lines
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


