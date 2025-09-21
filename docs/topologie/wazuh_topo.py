from diagrams import Diagram, Cluster, Edge
from diagrams.generic.os import LinuxGeneral
from diagrams.generic.network import Switch
from diagrams.generic.database import SQL
from diagrams.generic.place import Datacenter

graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "rankdir": "TB",  # Top -> Bottom
    "splines": "ortho",
}

node_attr = {
    "fontsize": "12",
    "shape": "box",
    "style": "filled",
    "fillcolor": "white",
}

colors = {
    "bastion": "#f0f8ff",
    "attacker": "#ffebee",
    "victim": "#f0fff0",
    "monitoring": "#fff8e1",
    "network": "#f0f0f0",
}

with Diagram("Topologie Blueteam Challenge - Bastion en bas",
             show=False, filename="topologie_bastion_bas",
             outformat="png", graph_attr=graph_attr, node_attr=node_attr):

    lab_kibanas = []

    # --- Labs en haut ---
    for i in range(1, 4):
        with Cluster(f"Lab {i} (VLAN {9+i})"):
            attacker = LinuxGeneral(f"Attacker{i}", fillcolor=colors["attacker"])
            dvwa = LinuxGeneral(f"DVWA{i}", fillcolor=colors["victim"])
            db = SQL(f"MariaDB{i}", fillcolor=colors["victim"])
            wazuh = Datacenter(f"Wazuh{i}", fillcolor=colors["monitoring"])
            es = SQL(f"Elastic{i}", fillcolor=colors["monitoring"])
            kib = Datacenter(f"Kibana{i}", fillcolor=colors["monitoring"])

            attacker >> dvwa >> db
            dvwa >> wazuh >> es >> kib

            lab_kibanas.append(kib)

    # --- Réseau et bastion en bas ---
    with Cluster("Accès / Réseau", graph_attr={"rank": "sink"}):
        switch = Switch("Switch VLANs", fillcolor=colors["network"])
        bastion = LinuxGeneral("Bastion / Prof", fillcolor=colors["bastion"])

    # Liens
    bastion >> Edge(color="blue", style="bold") >> switch
    for kib in lab_kibanas:
        switch >> Edge(color="blue", style="dotted") >> kib

