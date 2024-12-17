using Powsybl
using Test

network = Powsybl.Network.create_ieee9()

@test network.id == "ieee9cdf"
@test network.name == "ieee9cdf"
@test network.source_format == "IEEE-CDF"
@test network.forecast_distance == 0
@test network.case_date ≈ 1.240704e9

lines = Powsybl.Network.get_lines(network)
@test names(lines) == ["id", "name", "r", "x", "g1", "b1", "g2", "b2", "p1", "q1", "i1", "p2", "q2",
 "i2", "voltage_level1_id", "voltage_level2_id", "bus1_id", "bus2_id", "connected1", "connected2"]

@test lines[:, "id"] == ["L7-8-0", "L9-8-0", "L7-5-0", "L9-6-0", "L5-4-0", "L6-4-0"]
@test lines[:, "bus1_id"] == ["VL2_1", "VL3_1", "VL2_1", "VL3_1", "VL5_0", "VL6_0"]
