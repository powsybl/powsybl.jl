using Powsybl
using CxxWrap
using Test

network = Powsybl.Network.NetworkCreationUtils.create_ieee9()
network_metadata = Powsybl.Network.get_network_metadata(network)

@test Powsybl.id(network_metadata[]) == "ieee9cdf"
@test Powsybl.name(network_metadata[]) == "ieee9cdf"
@test Powsybl.source_format(network_metadata[]) == "IEEE-CDF"
@test Powsybl.forecast_distance(network_metadata[]) == 0
@test Powsybl.case_date(network_metadata[]) ≈ 1.240704e9

lines = Powsybl.Network.get_lines(network)
@test names(lines) == ["id", "name", "r", "x", "g1", "b1", "g2",
 "b2", "p1", "q1", "i1", "p2", "q2", "i2", "voltage_level1_id",
  "voltage_level2_id", "bus1_id", "bus2_id"]

@test lines[:, "id"] == ["L7-8-0", "L9-8-0", "L7-5-0", "L9-6-0", "L5-4-0", "L6-4-0"]
@test lines[:, "bus1_id"] == ["VL2_1", "VL3_1", "VL2_1", "VL3_1", "VL5_0", "VL6_0"]
