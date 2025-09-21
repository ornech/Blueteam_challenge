# wazuh_3labs_topo.py
# Génère une topologie Wazuh + 3 labs (DVWA, Agent, Attacker) en PNG/SVG via diagrams.
from diagrams import Diagram, Cluster
from diagrams.generic.network import Switch
from diagrams.generic.compute import Rack
from diagrams.onprem.client import Client

GROUPS = 3
MANAGER_IP = "10.10.0.10"
PROXY_IP = "10.10.0.20"

def agent_ip(g): return f"10.10.{g}.10"
def service_ip(g): return f"10.10.{g}.20"
def attacker_ip(g): return f"10.10.{g}.30"
def vlan_id(g): return 100 + g

output_path = "wazuh_3labs_topo"   # produces wazuh_3labs_topo.png (and .svg if you change extension)
with Diagram("Wazuh TP - 3 Labs Topology", show=False, filename=output_path, direction="LR"):
    sw = Switch("Switch / Router (trunk)")
    mgr = Rack(f"Wazuh Manager\n{MANAGER_IP}\n(Elastic+Kibana)")
    proxy = Client(f"Proxy / Kibana\n{PROXY_IP}")

    for i in range(1, GROUPS + 1):
        with Cluster(f"VLAN {vlan_id(i)} - Lab {i}\n10.10.{i}.0/24"):
            ag = Rack(f"Agent{i}\n{agent_ip(i)}")
            svc = Rack(f"DVWA{i}\n{service_ip(i)}")
            att = Client(f"Attacker{i}\n{attacker_ip(i)}")
            # local interactions inside lab
            att >> ag
            svc >> ag
            # reporting to manager
            ag >> mgr

    # core links
    sw >> mgr
    sw >> proxy
