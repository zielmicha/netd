import os
import conf/exceptions
import netd/core
import dbus, dbus/loop

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

proc main*() =
  let params = os.commandLineParams()
  if params.len != 1:
    echo "Usage: netd config-file"
    quit 1
  let config = params[0]

  let manager = NetworkManager.create

  manager.registerPlugin(LinkManager)
  manager.registerPlugin(RoutingManager)

  manager.registerPlugin(DbusCorePlugin)

  manager.registerPlugin(LinkBridgePlugin)
  manager.registerPlugin(LinkVethPlugin)
  manager.registerPlugin(LinkHwPlugin)

  manager.registerPlugin(AddrManager)
  manager.registerPlugin(AddrStaticPlugin)
  manager.registerPlugin(AddrDhcpPlugin)

  let bus = getBus(dbus.DBUS_BUS_SYSTEM)
  let mainLoop = MainLoop.create(bus)

  manager.getPlugin(DbusCorePlugin).init(bus)

  try:
    manager.loadConfig(config)
    manager.reload()
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()

  mainLoop.runForever()
