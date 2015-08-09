import netd/core, netd/link, netd/iproute, netd/routing
import conf/ast
import commonnim

type AddrStaticPlugin* = ref object of Plugin

proc create*(t: typedesc[AddrStaticPlugin], manager: NetworkManager): AddrStaticPlugin =
  new(result)
  result.manager = manager

method configureInterfaceAdress*(self: AddrStaticPlugin, iface: ManagedInterface, config: Suite): bool =
  if not config.hasCommandWithName("static"):
    return false

  ipAddrFlush(iface.interfaceName)

  for staticCommand in config.commandsWithName("static"):
    let body = staticCommand.args.unpackSeq1().suite
    let address = body.singleValue("address", required=true).stringValue
    let gateway = body.singleValue("gateway", required=false).stringValue

    ipAddrAdd(iface.interfaceName, address)
    ipLinkUp(iface.interfaceName)

    if gateway != nil:
      # TODO: respect default_route
      # TODO: respect namespaces
      self.manager.getPlugin(RoutingManager).addDefaultGateway(gateway)

  return true
