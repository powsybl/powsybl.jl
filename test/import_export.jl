using Powsybl
using Test

network = Powsybl.Network.load("simple-eu.xiidm")
@test network.name == "simple-eu"

Powsybl.Network.save(network, "simple-eu.mat", "MATPOWER")
network_matpower = Powsybl.Network.load("simple-eu.mat")
@test network_matpower.name == "simple-eu"

Powsybl.Network.save(network, "simple-eu.zip", "CGMES")
network_cgmes = Powsybl.Network.load("simple-eu.zip")
@test network_cgmes.name == "urn:uuid:simple-eu_N_EQUIPMENT_2024-09-25T12:47:58Z_1_1D__FM"