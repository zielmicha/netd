import tables, typetraits, strutils, os
import netd/config
import conf/ast, conf/parse, conf/exceptions

type
  NetworkManager* = ref object
    plugins: OrderedTable[string, Plugin]
    mainConfig: Suite
    pluginGeneratedConfigs: Table[string, Suite]
    config*: Suite

  Plugin* = ref object {.inheritable.}
    name*: string
    manager*: NetworkManager

method reload*(plugin: Plugin) {.base.} =
  discard

method validateConfig*(plugin: Plugin) {.base.} =
  discard

method exit*(plugin: Plugin) {.base.} =
  discard

method info*(plugin: Plugin) {.base.} =
  echo "Plugin %1" % plugin.name

proc addPlugin*(manager: NetworkManager, name: string, plugin: Plugin) =
  echo "adding plugin $1" % name
  plugin.name = name
  manager.plugins[name] = plugin

proc getPlugin*(manager: NetworkManager, name: string): Plugin =
  manager.plugins[name]

proc getPlugin*[T](manager: NetworkManager, typ: typedesc[T]): T =
  manager.getPlugin(name(typ)).T

proc getPlugin*[T](plugin: Plugin, typ: typedesc[T]): auto =
  plugin.manager.getPlugin(typ)

iterator iterPlugins*(manager: NetworkManager): Plugin =
  for k, v in manager.plugins:
    yield v

template registerPlugin*(manager: NetworkManager, plugin: typedesc) =
  manager.addPlugin(name(plugin), plugin.create(manager))

template callAllPlugins*(self, funcname) =
  for plugin in self.manager.iterPlugins:
    funcname(plugin)

proc create*(t: typedesc[NetworkManager]): NetworkManager =
  new(result)
  result.plugins = initOrderedTable[string, Plugin]()
  result.pluginGeneratedConfigs = initTable[string, Suite]()

proc loadConfig*(self: NetworkManager, filename: string) =
  let f = open(filename)
  defer: f.close
  self.mainConfig = parse(f.readAll(), filename, mainCommands)

proc setPluginGeneratedConfig*(self: NetworkManager, typ: typedesc, config: Suite) =
  self.pluginGeneratedConfigs[name(typ)] = config

proc mergeConfigs(self: NetworkManager) =
  self.config = Suite(commands: @[])
  self.config.commands &= self.mainConfig.commands
  for config in self.pluginGeneratedConfigs.values:
    self.config.commands &= config.commands

proc validateConfig*(self: NetworkManager) =
  self.mergeConfigs()

  for name, plugin in self.plugins:
    plugin.validateConfig

proc reload*(self: NetworkManager) =
  self.mergeConfigs()
  self.validateConfig()

  for name, plugin in self.plugins:
    plugin.reload

proc exit*(self: NetworkManager) =
  for name, plugin in self.plugins:
    plugin.exit

proc getScriptPath*(name: string): string =
  getAppDir() & "/../scripts/" & name
