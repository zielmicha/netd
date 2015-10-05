import netd/core, netd/link, netd/iproute, netd/routing, ipaddress, netd/processmanager
import netd/dbuscore, dbus, dbus/def
import conf/ast
import commonnim, options, strutils, tables

include netd/addrdhcpconfig

type
  DhcpConfig = object
    case configured: bool
    of true:
      ipInterface: IpInterface
      gateway: IpAddress
    of false:
      discard

  AddrDhcpPlugin* = ref object of Plugin
    processManager: ProcessManager
    waitingConfigs: Table[string, DhcpConfig]

proc create*(t: typedesc[AddrDhcpPlugin], manager: NetworkManager): AddrDhcpPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()
  result.waitingConfigs = initTable[string, DhcpConfig]()

proc Callback(self: AddrDhcpPlugin, abstractName: string,
              event: string, ip: string, subnet: string, router: string) =
  echo repr(@[abstractName, event, ip, subnet, router])
  let ifaceOpt = self.getPlugin(LinkManager).listLivingInterfaces().findLivingInterface(abstractName)
  if ifaceOpt.isSome:
    let iface: InterfaceName = ifaceOpt.get
    var reload = false

    if event == "deconfig":
      reload = true
      self.waitingConfigs[abstractName] = DhcpConfig(configured: false)
    if event == "bound" or event == "renew":
      reload = true
      self.waitingConfigs[abstractName] = DhcpConfig(configured: true,
                                                     ipInterface: (parseAddress(ip), parseAddress(subnet).asMask),
                                                     gateway: parseAddress(router))

    if reload:
      self.manager.reload()
  else:
    echo "interface %1 disappeared!" % abstractName


let dhcpClientDef = newInterfaceDef(AddrDhcpPlugin)
dhcpClientDef.addMethod(Callback, [
  ("abstractName", string), ("event", string), ("ip", string), ("subnet", string), ("router", string)], [])

method dbusInit*(self: AddrDhcpPlugin) =
  self.getPlugin(DbusCorePlugin).netdObject.addInterface("net.networkos.netd.DhcpClient", dhcpClientDef, self)

method configureInterfaceAdress*(self: AddrDhcpPlugin, iface: ManagedInterface, config: Suite): bool =
  if not config.hasCommandWithName("dhcp"):
    return false

  ipLinkUp(iface.interfaceName)
  self.processManager.pokeProcess(key=iface.abstractName,
                                  cmd= @["busybox", "udhcpc",
                                         "--script", getScriptPath("udhcpc-callback.sh"),
                                         "--foreground",
                                         "--interface", iface.kernelName],
                                  env= {"abstractName": iface.abstractName},
                                  namespace=iface.namespaceName)

  if self.waitingConfigs.hasKey(iface.abstractName):
    let config = self.waitingConfigs[iface.abstractName]

    if not config.configured:
      ipAddrFlush(iface.interfaceName)
    else:
      ipAddrFlush(iface.interfaceName)
      ipAddrAdd(iface.interfaceName, $config.ipInterface)
      self.manager.getPlugin(RoutingManager).addDefaultGateway(via= $config.gateway,
                                                               forIp=config.ipInterface.address,
                                                               namespace=iface.namespaceName)

  return true

method afterSetupInterfaces*(self: AddrDhcpPlugin) =
  self.processManager.teardownNotPoked()
  self.waitingConfigs = initTable[string, DhcpConfig]()

method exit*(self: AddrDhcpPlugin) =
  self.processManager.exit()
