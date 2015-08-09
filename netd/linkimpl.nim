import netd/iproute
import conf/ast
import tables, strutils, sequtils

proc getRename*(identifier: string, suite: Suite): InterfaceName =
  let newName = suite.singleValue("name", required=false).stringValue
  let namespace = suite.singleValue("namespace", required=false).stringValue
  let name = if newName != nil: newName else: identifier
  return (namespace: namespace, name: name)

proc applyRename(interfaceName: InterfaceName, target: InterfaceName) =
  let isAlreadyOk = (target.namespace == interfaceName.namespace) and (target.name == interfaceName.name)
  if not isAlreadyOk:
    rename(interfaceName, target.name, target.namespace)

proc applyRename(interfaceName: InterfaceName, suite: Suite): InterfaceName =
  result = getRename(interfaceName.name, suite)
  applyRename(interfaceName, result)

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
  result.kernelName = ifaceName.name
  result.namespaceName = ifaceName.namespace

  let props = readAliasProperties(ifaceName)
  result.abstractName = props["abstractName"]
  result.isSynthetic = props["isSynthetic"] == "true"

proc listLivingInterfaces(): seq[LivingInterface] =
  result = @[]
  for name in listSysfsInterfaces():
    result.add infoAboutLivingInterface(name)

proc findLivingInterface(self: LinkManager, abstractName: string): Option[InterfaceName] =
  for candidate in listLivingInterfaces():
    if candidate.abstractName == abstractName:
      return some(candidate.interfaceName)

  return none(InterfaceName)

proc removeUnusedInterfaces(managed: seq[ManagedInterface]) =
  let allInterfaces = listLivingInterfaces()
  var managedNames = initCountTable[string]()

  for iface in managed:
    echo "ManagedInterface $1" % $iface
    managedNames.inc iface.abstractName

  for iface in allInterfaces:
    if iface.isSynthetic and managedNames[iface.abstractName] == 0:
      ipLinkDel(iface.interfaceName)

proc setupNamespaces(self: LinkManager) =
  let namespaces = toSeq(listNamespaces())
  echo "existing network namespaces: ", $namespaces
  if "root" notin namespaces:
    createRootNamespace()

  for cmd in self.manager.config.commandsWithName("namespace"):
    let nsname = cmd.args.unpackSeq1.stringValue
    if nsname notin namespaces:
      ipNetnsCreate(nsname)

proc gatherInterfacesAll(self: LinkManager): seq[ManagedInterface] =
  result = @[]
  for plugin in self.manager.iterPlugins:
    result &= plugin.gatherInterfaces()

method reload(self: LinkManager) =
  echo "reloading LinkManager"
  self.setupNamespaces()
  let managedInterfaces = self.gatherInterfacesAll()
  echo "managed interfaces: ", $managedInterfaces
  removeUnusedInterfaces(managedInterfaces)
  self.callAllPlugins(beforeSetupInterfaces)
  self.callAllPlugins(setupInterfaces)
  self.callAllPlugins(afterSetupInterfaces)
