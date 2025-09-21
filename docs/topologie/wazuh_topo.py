from diagrams import Diagram, Cluster
from diagrams.generic.network import Switch
from diagrams.generic.compute import Rack
from diagrams.generic.blank import Blank
from diagrams.onprem.client import Client

with Diagram("Topologie TP Wazuh", show=False, filename="wazuh_topo", direction="TB"):
    sw = Switch("Switch / Router (trunk)")
    mgr = Rack("Wazuh Manager\n(Elastic + Kibana)")
    prof = Client("Prof / Kibana Web")

    with Cluster("VLAN 10 - Groupe 1"):
        agent1 = Rack("Agent1 (Linux)")
        attacker1 = Client("Attacker1 (Kali)")

    with Cluster("VLAN 11 - Groupe 2"):
        agent2 = Rack("Agent2 (Linux)")
        attacker2 = Client("Attacker2 (Kali)")

    # Connexions
    sw >> mgr
    sw >> prof
    agent1 >> mgr
    agent2 >> mgr
    attacker1 >> agent1
    attacker2 >> agent2
