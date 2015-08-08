import netd/core, netd/link, netd/iproute, netd/routing
import conf/ast
import commonnim

type AddrStaticPlugin* = ref object of Plugin
    manager: NetworkManager

proc create*(t: typedesc[AddrStaticPlugin], manager: NetworkManager): AddrStaticPlugin =
  new(result)
  result.manager = manager

method configureInterface*(self: AddrStaticPlugin, iface: ManagedInterface, config: Suite) =
  if not config.hasCommandWithName("static"):
    return

  ipAddrFlush(iface.interfaceName)

  for staticCommand in config.commandsWithName("static"):
    let body = staticCommand.args.unpackSeq1().suite
    let address = body.singleValue("address", required=true).stringValue
    let gateway = body.singleValue("gateway", required=false).stringValue

    ipLinkUp(iface.interfaceName)
    ipAddrAdd(iface.interfaceName, address)

    if gateway != nil:
      # TODO: respect default_route
      # TODO: respect namespaces
      self.manager.getPlugin(RoutingManager).addDefaultGateway(gateway)
