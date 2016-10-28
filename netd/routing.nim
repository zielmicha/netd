import reactor/ipaddress, options, conf/ast
import netd/core, netd/iproute, netd/link

type
  RoutingManager* = ref object of Plugin
    routes: seq[tuple[namespace: NamespaceName, via: string]]

proc create*(t: typedesc[RoutingManager], manager: NetworkManager): RoutingManager =
  new(result)
  result.manager = manager

proc defaultRoute(kind: IpKind): IpInterface =
  case kind:
    of ip4:
      return parseInterface("0.0.0.0/0")
    of ip6:
      return parseInterface("::/0")

proc addRoute(self: RoutingManager, iface: ManagedInterface, address: IpAddress,
              network: IpInterface, via=none(IpAddress)) =
  if via.isSome:
    ipRouteAdd(iface.namespaceName, $network,
               linkLocal=false, target= $via.get, src= $address)
  else:
    ipRouteAdd(iface.namespaceName, $network,
               linkLocal=true, target=iface.kernelName, src= $address)

proc configureInterfaceRoutes*(self: RoutingManager, config: Suite,
        iface: ManagedInterface,
        address: IpAddress,
        overrideGateway=none(IpAddress)) =
  # TODO: handle route removal, now they are flushed by ipAddrFlush
  # ipRouteFlush(iface.interfaceName)
  var defaultRouteAdded = false

  for cmd in config.commandsWithName("route"):
    let network = cmd.args[0].stringValue.parseInterface
    let rest = cmd.args[1].command
    if network.mask == 0:
      defaultRouteAdded = true

    case rest.name:
      of "via":
        let via = parseAddress(rest.args[0].stringValue)
        self.addRoute(iface,
                      address=address,
                      network=network,
                      via=some(via))
      of "local":
        self.addRoute(iface,
                      address=address,
                      network=network)
      else: discard

  let gateway = config.singleValue("gateway", required=false).stringValue
  if gateway != nil:
    defaultRouteAdded = true
    self.addRoute(iface,
                  address=address,
                  network=defaultRoute(address.kind),
                  via=some(parseAddress(gateway)))

  if not defaultRouteAdded and overrideGateway.isSome:
    self.addRoute(iface, address=address,
                  network=defaultRoute(address.kind),
                  via=some(overrideGateway.get))

method beforeSetupInterfaces*(self: RoutingManager) =
  discard

method afterSetupInterfaces*(self: RoutingManager) =
  discard
