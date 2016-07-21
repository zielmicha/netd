import os
import conf/exceptions
import netd/core
import dbus, dbus/lowlevel, dbus/loop

import netd/api/apicore

method runMain*(plugin: Plugin, params: seq[string]): bool {.base.} =
  return false

# Plugins
import netd/link
import netd/linkhw
import netd/linkveth
import netd/linkbridge
import netd/addr
import netd/addrstatic
import netd/addrdhcp
import netd/routing
import netd/dbuscore
import netd/fragments
import netd/openvpnptp
import netd/iptables
import netd/dhcpserver
import netd/wireless

proc baseMain(manager: NetworkManager, params: seq[string]): bool =
  let bus = getUniqueBus(DBUS_BUS_SYSTEM, "net.networkos.netd")
  let coreRemote = NetNetworkosNetdCoreRemote.get(bus, ObjectPath("/net/networkos/netd"))
  case params[0]:
    of "daemon":
      if params.len > 2:
        echo "expected exactly at most one argument"
        quit 1

      createDir(RunPath)
      let config = if params.len == 2: params[1] else: "/etc/netd.conf"
      let bus = getBus(dbus.DBUS_BUS_SYSTEM)
      let mainLoop = MainLoop.create(bus)

      manager.getPlugin(DbusCorePlugin).init(bus)

      try:
        manager.loadConfig(config)
        manager.reload()
      except ConfError:
        (ref ConfError)(getCurrentException()).printError()

      mainLoop.runForever()
      return true
    of "loadconfig":
      coreRemote.LoadConfig(params[1])
      return true
    of "reload":
      coreRemote.Reload()
      return true
    else:
      return false

proc main*() =
  let params = os.commandLineParams()

  if params.len < 1:
    echo "Usage: netd command [args...]"
    quit 1

  let manager = NetworkManager.create

  manager.registerPlugin(LinkManager)
  manager.registerPlugin(RoutingManager)

  manager.registerPlugin(DbusCorePlugin)
  manager.registerPlugin(FragmentsPlugin)

  manager.registerPlugin(LinkBridgePlugin)
  manager.registerPlugin(LinkVethPlugin)
  manager.registerPlugin(LinkHwPlugin)
  manager.registerPlugin(OpenvpnPtpPlugin)

  manager.registerPlugin(AddrManager)
  manager.registerPlugin(AddrStaticPlugin)
  manager.registerPlugin(AddrDhcpPlugin)

  manager.registerPlugin(IptablesPlugin)
  manager.registerPlugin(DhcpServerPlugin)
  manager.registerPlugin(WirelessPlugin)

  var ok = manager.baseMain(params)
  for plugin in manager.iterPlugins:
    ok = ok or plugin.runMain(params)

  if not ok:
    stderr.writeLine("netd: unexpected command")
    quit 1
