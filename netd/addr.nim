import netd/core, netd/link, netd/iproute
import conf/ast

type AddrManager* = ref object of Plugin

method configureInterfaceAdress*(self: Plugin, iface: ManagedInterface, config: Suite): bool {.base.} =
  ## Configure addresses for given `ManagedInterface`.
  ## Return true if this plugin will handle addressing for this interface.

# impl:

proc create*(t: typedesc[AddrManager], manager: NetworkManager): AddrManager =
  new(result)
  result.manager = manager

method configureInterface*(self: AddrManager, iface: ManagedInterface, config: Suite) =
  var taken: bool = false
  for plugin in self.manager.iterPlugins:
    if plugin.configureInterfaceAdress(iface, config):
      if taken:
        raise newConfError(config, "multiple addressing plugins used")
      taken = true

  if not taken:
    # this should also remove routes
    ipAddrFlush(iface.interfaceName)
    ipLinkUp(iface.interfaceName)
