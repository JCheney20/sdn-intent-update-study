from enum import Enum
from ipaddress import IPv4Address, IPv4Network
from networkx import DiGraph
from typing import Any


class FlowRuleException(Exception):
    pass


class ConnectionException(Exception):
    pass


class NodeColor(Enum):
    SWITCH = "skyblue"
    CONNECTOR = "lightgray"
    HOST = "lightgreen"


class Action(Enum):
    INIT = 1
    ADD = 2
    REMOVE = 3


class Connectivity(Enum):
    CONNECTED = 1
    DISCONNECTED = 2


class ConnectivityExpectation(Enum):
    NORMAL = 1
    EXTRA = 2
    UNKNOWN = 3


class Node:
    def __init__(self, mac: str) -> None:
        self.mac = mac

    def __repr__(self) -> str:
        return f"{self.mac}"


class Device(Node):
    pass


class FlowRule:
    def __init__(
        self,
        action: Action,
        ingress: Device | None,
        egress: Device | None,
        source_match: IPv4Network,
        dest_match: IPv4Network,
    ) -> None:
        if not ingress or not egress:
            raise Exception("Either ingress or egress of flow rule was None")

        self.ingress = ingress
        self.egress = egress
        self.action = action
        self.source_match = source_match
        self.dest_match = dest_match

    def packet_match(self, source: IPv4Address, dest: IPv4Address) -> bool:
        return source in self.source_match and dest in self.dest_match

    def __repr__(self) -> str:
        return f"[FlowRule:: Action: {self.action.name}; Ingress: {self.ingress.mac}; Egress: {self.egress.mac}]"


class Host(Device):
    def __init__(self, mac: str, ip: IPv4Address) -> None:
        super().__init__(mac)
        self.ip = ip


class Switch(Device):
    def __init__(self, mac: str) -> None:
        super().__init__(mac)
        self.init_flowrules: list[FlowRule] = []
        self.new_flowrules_add: list[FlowRule] = []
        self.new_flowrules_rm: list[FlowRule] = []

    def add_flow_rules(self, *flowrules: FlowRule) -> None:
        for flowrule in flowrules:
            if flowrule.action is Action.INIT:
                self.init_flowrules.append(flowrule)
            elif flowrule.action is Action.REMOVE:
                self.new_flowrules_rm.append(flowrule)
            elif flowrule.action is Action.ADD:
                self.new_flowrules_add.append(flowrule)


class ConnectionNode(Node):
    def __init__(self, from_switch: Device, to_switch: Device):
        # need to sort the switches so the pair always gets the same name
        switches = [from_switch.mac, to_switch.mac]
        switches.sort()

        super().__init__("-".join(switches))
        self.from_switch = from_switch
        self.to_switch = to_switch


class ConnectionStatus:
    def __init__(
        self,
        source: Host,
        dest: Host,
        status: Connectivity,
        expectation: ConnectivityExpectation,
        path: list[Any],
        updated_switches: tuple[Switch, ...],
        topo: DiGraph,
    ) -> None:
        self.source = source
        self.dest = dest
        self.status = status
        self.path = path
        self.updated_switches = updated_switches
        self.topo = topo
        self.expectation = expectation

    def __repr__(self) -> str:
        return f"[{self.source}, {self.dest}, {self.status}, {self.path}, {self.updated_switches}]"
