import os
import netd/core

# Plugins
import netd/link
import netd/linkdev
import netd/addrstatic

proc main*() =
  let params = os.commandLineParams()
  if params.len != 1:
    echo "Usage: netd config-file"
    quit 1
  let config = params[0]

  let manager = NetworkManager.create
  manager.registerPlugin(LinkManager)
  manager.registerPlugin(LinkDevPlugin)
  manager.registerPlugin(AddrStaticPlugin)

  if manager.loadConfig(config):
    manager.run
