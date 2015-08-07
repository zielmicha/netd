import netd/core, netd/link
import conf/ast

type AddrStaticPlugin* = ref object of Plugin
    manager: NetworkManager

proc create*(t: typedesc[AddrStaticPlugin], manager: NetworkManager): AddrStaticPlugin =
  new(result)
  result.manager = manager

method configureInterface*(plugin: AddrStaticPlugin, iface: ManagedInterface, config: Suite) =
  nil
