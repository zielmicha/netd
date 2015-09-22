import netd/core, netd/link, netd/iproute, netd/routing, ipaddress
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
    let addressStr = body.singleValue("address", required=true).stringValue
    let gateway = body.singleValue("gateway", required=false).stringValue

    let ipInterface = addressStr.parseInterface

    ipAddrAdd(iface.interfaceName, $ipInterface)
    ipLinkUp(iface.interfaceName)

    if gateway != nil:
      self.manager.getPlugin(RoutingManager).addDefaultGateway(via=gateway,
                                                               forIp=ipInterface.address,
                                                               namespace=iface.namespaceName)

  return true
