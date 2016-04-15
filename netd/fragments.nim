import dbus, dbus/def
import netd/core, netd/dbuscore, netd/config
import conf/exceptions, conf/ast, conf/parse
import tables

type
  FragmentsPlugin* = ref object of Plugin
    fragments: OrderedTable[string, Suite]

proc create*(t: typedesc[FragmentsPlugin], manager: NetworkManager): FragmentsPlugin =
  new(result)
  result.manager = manager
  result.fragments = initOrderedTable[string, Suite]()

proc refreshConfig(self: FragmentsPlugin) =
  let config = Suite(commands: @[])
  for conf in self.fragments.values:
    if conf != nil:
      config.commands &= conf.commands
  self.manager.setPluginGeneratedConfig(FragmentsPlugin, config)

proc loadFragment(self: FragmentsPlugin, name: string, config: string) =
  # TODO: store fragments in /run/netd to preserve them across reboots
  let previousValue = self.fragments.getOrDefault(name)
  self.fragments[name] = parse(config, "fragment " & name, mainCommands)
  self.refreshConfig()

  try:
    self.manager.validateConfig()
  except:
    # revert configuration
    self.fragments[name] = previousValue
    self.refreshConfig()
    raise

proc LoadFragment*(self: FragmentsPlugin, name: string, config: string) =
  try:
    self.loadFragment(name, config)
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()
    raise

let fragmentsDef = newInterfaceDef(FragmentsPlugin)
fragmentsDef.addMethod(LoadFragment, [("name", string), ("config", string)], [])

method dbusInit(self: FragmentsPlugin) =
  self.getPlugin(DbusCorePlugin).netdObject.
    addInterface("net.networkos.netd.Fragments", fragmentsDef, self)
