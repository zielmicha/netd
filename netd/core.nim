import tables, typetraits, strutils

type
  NetworkManager* = ref object
    plugins: Table[string, Plugin]

  Plugin* = ref object {.inheritable.}
    name*: string

method reload*(plugin: Plugin) =
  discard

method info*(plugin: Plugin) =
  echo "Plugin %1" % plugin.name

proc addPlugin*(manager: NetworkManager, name: string, plugin: Plugin) =
  echo "adding plugin $1" % name
  plugin.name = name
  manager.plugins[name] = plugin

proc getPlugin*[T](manager: NetworkManager, typ: typedesc[T]): T =
  manager.plugis[name(typ)].T

template registerPlugin*(manager: NetworkManager, plugin: typedesc) =
  manager.addPlugin(name(plugin), plugin.create(manager))

proc create*(t: typedesc[NetworkManager]): NetworkManager =
  new(result)
  result.plugins = initTable[string, Plugin]()
