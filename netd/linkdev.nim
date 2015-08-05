import netd/core
import netd/link

type
  LinkDevPlugin* = ref object of Plugin
    manager: NetworkManager

proc create*(t: typedesc[LinkDevPlugin], manager: NetworkManager): LinkDevPlugin =
  new(result)
  result.manager = manager

method gatherInterfaces*(plugin: LinkDevPlugin): seq[ManagedDevice] =
  nil
