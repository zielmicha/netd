import reactor/ipaddress
import netd/core, netd/link, netd/iproute, netd/routing, netd/processmanager
import netd/dbuscore, dbus, dbus/def, dbus/lowlevel
import conf/ast
import commonnim, options, strutils, tables, os

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

method runMain*(plugin: AddrDhcpPlugin, params: seq[string]): bool =
  if params[0] == "_dhcp_callback":
    let bus = getBus(DBUS_BUS_SYSTEM)
    let msg = makeCall("net.networkos.netd", ObjectPath("/net/networkos/netd"), "net.networkos.netd.DhcpClient", "Callback")
    msg.append(os.getenv("abstractName"))
    msg.append(params[1])
    msg.append(os.getenv("ip"))
    msg.append(os.getenv("subnet"))
    msg.append(os.getenv("router"))
    let reply = bus.sendMessageWithReply(msg).waitForReply
    defer: reply.close
    reply.raiseIfError

    return true
  else:
    return false

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
  let scriptPath = makeScript("dhcp-callback.sh", "#!/bin/sh\n" & getAppDir() & "/netd _dhcp_callback \"$1\"")
  self.processManager.pokeProcess(key=iface.abstractName,
                                  cmd= @["busybox", "udhcpc",
                                         "--script", scriptPath,
                                         "--foreground",
                                         "--interface", iface.kernelName],
                                  env= {"abstractName": iface.abstractName},
                                  namespace=iface.namespaceName)

  if self.waitingConfigs.hasKey(iface.abstractName):
    let dhcpConfig = self.waitingConfigs[iface.abstractName]

    if not dhcpConfig.configured:
      ipAddrFlush(iface.interfaceName)
    else:
      ipAddrFlush(iface.interfaceName)
      ipAddrAdd(iface.interfaceName, $dhcpConfig.ipInterface)

      self.manager.getPlugin(RoutingManager).configureInterfaceRoutes(
        config=config,
        iface=iface,
        address=dhcpConfig.ipInterface.address,
        overrideGateway=some(dhcpConfig.gateway))

  return true

method afterSetupInterfaces*(self: AddrDhcpPlugin) =
  self.processManager.teardownNotPoked()
  self.waitingConfigs = initTable[string, DhcpConfig]()

method exit*(self: AddrDhcpPlugin) =
  self.processManager.exit()
