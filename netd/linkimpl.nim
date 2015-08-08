import netd/iproute
import conf/ast
import tables, strutils, sequtils

proc gatherInterfacesAll(self: LinkManager): seq[ManagedInterface] =
  result = @[]
  for plugin in self.manager.iterPlugins:
    result &= plugin.gatherInterfaces()

proc applyRename(interfaceName: InterfaceName, suite: Suite): InterfaceName =
  let newName = suite.singleValue("name", required=false).stringValue
  let namespace = suite.singleValue("namespace", required=false).stringValue
  let name = if newName != nil: newName else: interfaceName.name
  let isAlreadyOk = (namespace == interfaceName.namespace) and (newName == nil or newName == interfaceName.name)
  if not isAlreadyOk:
    rename(interfaceName, name, namespace)
  return (namespace: namespace, name: name)

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

proc removeUnusedInterfaces(managed: seq[ManagedInterface]) =
  let allInterfaces = listLivingInterfaces()
  var managedNames = initCountTable[InterfaceName]()

  for iface in managed:
    echo "ManagedInterface $1" % $iface
    managedNames.inc iface.interfaceName

  for iface in allInterfaces:
    let interfaceName: InterfaceName = (namespace: iface.namespaceName, name: iface.kernelName)
    if iface.isSynthetic and managedNames[interfaceName] == 0:
      delete(interfaceName)

proc setupRootNs() =
  let namespaces = toSeq(listNamespaces())
  echo "existing network namespaces: ", $namespaces
  if "root" notin namespaces:
    createRootNamespace()

method reload(self: LinkManager) =
  echo "reloading LinkManager"
  setupRootNs()
  let managedInterfaces = self.gatherInterfacesAll()
  echo "managed interfaces: ", $managedInterfaces
  removeUnusedInterfaces(managedInterfaces)
