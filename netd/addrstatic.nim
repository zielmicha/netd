import reactor/ipaddress
import netd/core, netd/link, netd/iproute, netd/routing
import conf/ast
import commonnim

type AddrStaticPlugin* = ref object of Plugin

include netd/addrstaticconfig

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
    let peerAddress = body.singleValue("peer_address", required=false).stringValue

    let ipInterface = addressStr.parseInterface

    ipAddrAdd(iface.interfaceName, $ipInterface, peerAddress = peerAddress)
    ipLinkUp(iface.interfaceName)

    self.manager.getPlugin(RoutingManager).configureInterfaceRoutes(
      config=body,
      iface=iface,
      address=ipInterface.address)

  return true
