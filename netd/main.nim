import os
import netd/core
import netd/link
import netd/linkdev

proc main*() =
  let params = os.commandLineParams()
  if params.len != 1:
    echo "Usage: netd config-file"
    quit 1
  let config = params[0]

  let manager = NetworkManager.create
  manager.registerPlugin(LinkManager)
  manager.registerPlugin(LinkDevPlugin)
