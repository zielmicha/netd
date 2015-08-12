import netd/core, netd/iproute, ipaddress

type
  RoutingManager* = ref object of Plugin
    routes: seq[tuple[namespace: NamespaceName, via: string]]

proc create*(t: typedesc[RoutingManager], manager: NetworkManager): RoutingManager =
  new(result)
  result.manager = manager

proc addDefaultGateway*(self: RoutingManager, via: string, forIp: IpAddress, namespace: NamespaceName) =
  self.routes.add((namespace, via))

method beforeSetupInterfaces*(self: RoutingManager) =
  self.routes = @[]

method afterSetupInterfaces*(self: RoutingManager) =
  for route in self.routes:
    ipRouteAddDefault(route.namespace, via=route.via)
