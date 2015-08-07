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

proc readAliasProperties(name: string): Table[string, string] =
  result = initTable[string, string]()
  let data = readSysfsProperty(name, "ifalias")
  if data.startsWith("NETD,"):
    let parts = data.split(",")
    for i, part in parts:
      if i == 0:
        continue
      let split = part.find('=')
      if split != -1:
        result[part[0..split]] = part[split+1..^1]

proc writeAliasProperties(name: string, prop: Table[string, string]) =
  var s = "NETD"
  for k, v in prop:
    s.add("," & k & "=" & v)
  writeSysfsProperty(name, "ifalias", s)

proc infoAboutLivingInterface(name: string): LivingInterface =
  result.userName = name
  result.namespaceName = nil
  # TODO: parse alias
  let props = readAliasProperties(name)
  result.abstractName = props["abstractName"]
  result.isSynthetic = props["isSynthetic"] == "true"

proc listLivingInterfaces(): seq[LivingInterface] =
  # TODO: also walk other namespaces
  for name in listSysfsInterfaces():
    result.add infoAboutLivingInterface(name)

method reload(self: LinkManager) =
  echo "reloading LinkManager"
  let managedInterfaces = self.gatherInterfacesAll
  let allInterfaces = listLivingInterfaces
