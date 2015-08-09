import os
import conf/exceptions
import netd/core

# Plugins
import netd/link
import netd/linkhw
import netd/linkbridge
import netd/addr
import netd/addrstatic
import netd/routing

proc main*() =
  let params = os.commandLineParams()
  if params.len != 1:
    echo "Usage: netd config-file"
    quit 1
  let config = params[0]

  let manager = NetworkManager.create

  manager.registerPlugin(LinkManager)
  manager.registerPlugin(RoutingManager)

  manager.registerPlugin(LinkBridgePlugin)
  manager.registerPlugin(LinkHwPlugin)

  manager.registerPlugin(AddrManager)
  manager.registerPlugin(AddrStaticPlugin)


  try:
    manager.loadConfig(config)
    manager.run
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()
