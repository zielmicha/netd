import tables, typetraits, strutils
import netd/config
import conf/ast, conf/parse, conf/exceptions

type
  NetworkManager* = ref object
    plugins: Table[string, Plugin]
    config*: Suite

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

proc getPlugin*(manager: NetworkManager, name: string): Plugin =
  manager.plugins[name]

proc getPlugin*[T](manager: NetworkManager, typ: typedesc[T]): T =
  manager.getPlugin(name(typ)).T

iterator iterPlugins*(manager: NetworkManager): Plugin =
  for k, v in manager.plugins:
    yield v

template registerPlugin*(manager: NetworkManager, plugin: typedesc) =
  manager.addPlugin(name(plugin), plugin.create(manager))

proc create*(t: typedesc[NetworkManager]): NetworkManager =
  new(result)
  result.plugins = initTable[string, Plugin]()

proc loadConfig*(self: NetworkManager, filename: string): bool =
  try:
    let f = open(filename)
    defer: f.close
    self.config = parse(f.readAll(), filename, mainCommands)
    return true
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()
    return false

proc reload*(self: NetworkManager) =
  for name, plugin in self.plugins:
    plugin.reload

proc run*(self: NetworkManager) =
  self.reload
