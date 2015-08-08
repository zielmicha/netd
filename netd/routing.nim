import netd/core, netd/iproute

type
  RoutingManager* = ref object of Plugin
    manager: NetworkManager

proc create*(t: typedesc[RoutingManager], manager: NetworkManager): RoutingManager =
  new(result)
  result.manager = manager

proc addDefaultGateway*(self: RoutingManager, via: string) =
  ipRouteAddDefault(via)
