import netd/iproute
import tables, strutils, sequtils

proc gatherInterfacesAll(self: LinkManager): seq[ManagedInterface] =
  result = @[]
  for plugin in self.manager.iterPlugins:
    result &= plugin.gatherInterfaces()

type LivingInterface = object
  abstractName: string
  userName: string
  namespaceName: string
  isSynthetic: bool

proc readAliasProperties(ifaceName: InterfaceName): Table[string, string] =
  result = initTable[string, string]()
  let data = readSysfsProperty(ifaceName, "ifalias").strip
  if data.startsWith("NETD,"):
    let parts = data.split(",")
    for i, part in parts:
      if i == 0:
        continue
      let split = part.find('=')
      if split != -1:
        result[part[0..split-1]] = part[split+1..^1]

proc writeAliasProperties(ifaceName: InterfaceName, prop: Table[string, string]) =
  var s = "NETD"
  for k, v in prop:
    s.add("," & k & "=" & v)
  writeSysfsProperty(ifaceName, "ifalias", s)

proc infoAboutLivingInterface(ifaceName: InterfaceName): LivingInterface =
  result.userName = ifaceName.name
  result.namespaceName = ifaceName.namespace

  let props = readAliasProperties(ifaceName)
  result.abstractName = props["abstractName"]
  result.isSynthetic = props["isSynthetic"] == "true"

proc listLivingInterfaces(): seq[LivingInterface] =
  result = @[]
  for name in listSysfsInterfaces():
    result.add infoAboutLivingInterface(name)

proc removeUnusedInterfaces(managed: seq[ManagedInterface]) =
  let allInterfaces = listLivingInterfaces()
  var managedNames = initCountTable[InterfaceName]()

  for iface in managed:
    managedNames.inc iface.interfaceName

  for iface in allInterfaces:
    let interfaceName: InterfaceName = (namespace: iface.namespaceName, name: iface.userName)
    if iface.isSynthetic and managedNames[interfaceName] == 0:
      delete(interfaceName)

method reload(self: LinkManager) =
  echo "reloading LinkManager"
  let managedInterfaces = self.gatherInterfacesAll()
  removeUnusedInterfaces(managedInterfaces)
