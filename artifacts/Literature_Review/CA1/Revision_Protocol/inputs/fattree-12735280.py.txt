import logging
from networkx import (
    draw,
    Graph,
    spring_layout,
    get_node_attributes,
)

logger = logging.getLogger(__name__)

def create_cisco() -> Graph:
    logger.debug(f"Building the cisco topology")
    G = Graph()

    G.add_node("C1", type="core")
    G.add_node("C2", type="core")
    G.add_node("C3", type="core")
    G.add_node("C4", type="core")
    G.add_node("C5", type="core")
    G.add_node("C6", type="core")
    G.add_node("C7", type="core")
    G.add_node("C8", type="core")
    G.add_node("C9", type="core")
    G.add_node("C10", type="core")

    G.add_node("H1", type="host")
    G.add_node("H2", type="host")
    G.add_node("H3", type="host")
    G.add_node("H4", type="host")
    G.add_node("H5", type="host")
    G.add_node("H6", type="host")
    G.add_node("H7", type="host")
    G.add_node("H8", type="host")
    G.add_node("H9", type="host")
    G.add_node("H10", type="host")
    G.add_node("H11", type="host")
    G.add_node("H12", type="host")

    G.add_edge("C7", "C8")
    G.add_edge("C7", "C9")
    G.add_edge("C7", "C10")

    G.add_edge("C8", "C9")
    G.add_edge("C8", "C10")

    G.add_edge("C1", "C9")

    G.add_edge("C9", "C10")
    G.add_edge("C9", "C2")
    G.add_edge("C9", "C3")
    G.add_edge("C9", "C6")

    G.add_edge("C10", "C2")
    G.add_edge("C10", "C3")
    G.add_edge("C10", "C4")

    G.add_edge("C4", "C5")

    G.add_edge("H1", "C1")

    G.add_edge("H2", "C1")
    G.add_edge("H2", "C2")

    G.add_edge("H3", "C6")
    G.add_edge("H4", "C6")

    G.add_edge("H5", "C2")

    G.add_edge("H6", "C2")

    G.add_edge("H7", "C2")
    G.add_edge("H7", "C3")

    G.add_edge("H8", "C3")

    G.add_edge("H9", "C5")
    G.add_edge("H10", "C5")

    G.add_edge("H11", "C4")
    G.add_edge("H12", "C4")

    return G


def create_ministanford() -> Graph:
    logger.debug(f"Building the ministanford topology")
    G = Graph()

    G.add_node("C1", type="core")
    G.add_node("C2", type="core")
    G.add_edge("C1", "C2")

    for a in range(3, 8):
        G.add_node(f"A{a}", type="aggregation")
        G.add_edge(f"A{a}", "C1")

    for a in range(8, 13):
        G.add_node(f"A{a}", type="aggregation")
        G.add_edge(f"A{a}", "C2")

    for e in range(1, 14):
        G.add_node(f"E{e}", type="edge")

    G.add_edge(f"E1", "A6")
    G.add_edge(f"E1", "A8")
    G.add_edge(f"E2", "A3")
    G.add_edge(f"E3", "A6")
    G.add_edge(f"E3", "A11")
    G.add_edge(f"E4", "A7")
    G.add_edge(f"E4", "A12")
    G.add_edge(f"E5", "A4")
    G.add_edge(f"E5", "A9")
    G.add_edge(f"E6", "A5")
    G.add_edge(f"E6", "A10")
    G.add_edge(f"E7", "A4")
    G.add_edge(f"E8", "A6")
    G.add_edge(f"E9", "A3")
    G.add_edge(f"E9", "A8")
    G.add_edge(f"E10", "A5")
    G.add_edge(f"E10", "A9")
    G.add_edge(f"E11", "A10")
    G.add_edge(f"E12", "A6")
    G.add_edge(f"E12", "A11")
    G.add_edge(f"E13", "A7")
    G.add_edge(f"E13", "A12")


    for e in range(1, 14):
        G.add_node(f"H{e*2}", type="host")
        G.add_node(f"H{e*2-1}", type="host")
        G.add_edge(f"H{e*2}", f"E{e}")
        G.add_edge(f"H{e*2-1}", f"E{e}")

    return G

def create_fat_tree(ports_per_switch: int) -> Graph:
    logger.debug(f"Building fat tree with k={ports_per_switch}")
    G = Graph()

    half_of_ports = ports_per_switch // 2

    # Number of core switches
    core_switches = half_of_ports**2

    # Add core switches
    for c in range(core_switches):
        G.add_node(f"C{c}", type="core")

    # iterate over each pod
    for pod in range(ports_per_switch):
        create_agg_switches(G, ports_per_switch, pod)
        create_edge_switches_and_hosts(G, ports_per_switch, pod)

    return G


def draw_fat_tree(topology):
    pos = spring_layout(topology)
    node_colors = {
        "core": "red",
        "pod": "blue",
        "aggregation": "green",
        "edge": "yellow",
        "host": "gray",
    }
    node_types = get_node_attributes(topology, "type")
    colors = [node_colors[node_types[node]] for node in topology.nodes]

    draw(topology, pos, node_color=colors, with_labels=True)
    plt.show()


def create_agg_switches(G: Graph, ports_per_switch: int, pod: int):
    half_of_ports = num_agg_switches = ports_per_switch // 2

    counter = 0
    for a_id in range(num_agg_switches):
        agg_switch = f"A{pod}-{a_id}"

        logger.debug("Adding agg switch: %s", agg_switch)
        G.add_node(agg_switch, type="aggregation")

        # connect agg_switch to k/2 of core_switches
        for c_id in range(counter, counter + half_of_ports):
            G.add_edge(f"C{c_id}", agg_switch)
        counter += half_of_ports


def create_edge_switches_and_hosts(G: Graph, ports_per_switch: int, pod: int):
    half_of_ports = num_edge_switches = ports_per_switch // 2

    counter = 0
    for e_id in range(num_edge_switches):
        edge_switch = f"E{pod}-{e_id}"
        logger.debug("Adding edge switch: %s", edge_switch)
        G.add_node(edge_switch, type="edge")

        # connect edge_switch to k/2 of agg_switches
        for a_id in range(half_of_ports):
            G.add_edge(f"A{pod}-{a_id}", edge_switch)
        counter += half_of_ports

        for h_id in range(half_of_ports):
            host = f"H{pod}-{e_id}-{h_id}"
            logger.debug("Adding host: %s", host)

            # create hosts
            G.add_node(host, type="host")

            # connect host to edge
            G.add_edge(host, edge_switch)
