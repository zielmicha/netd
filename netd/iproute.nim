# iproute2 cheatsheet: http://baturin.org/docs/iproute2
# netlink overview: http://1984.lsi.us.es/~pablo/docs/spae.pdf
import os, osproc, tables, strutils, posix, morelinux
import subprocess, commonnim

type
  NamespaceName* = string not nil
  ## Location of a kernel interface.
  InterfaceName* = tuple[namespace: NamespaceName, name: string]

type NsRestoreData = tuple[mntFd: cint, netFd: cint, path: string]

const RootNamespace*: NamespaceName = "root"

proc nsNilToRoot*(name: string): NamespaceName =
  if name == nil:
    return RootNamespace
  else:
    return name

proc saveNamespace(): NsRestoreData =
  result.mntFd = saveNs(nsMnt)
  result.netFd = saveNs(nsNet)
  result.path = getCurrentDir()

proc nsDbg() =
  echo "nsDebug"
  for kind, path in walkDir("/sys/class/net"):
    echo path

proc enterNamespace(namespaceName: NamespaceName) =
  setNetNs(namespaceName)
  unshare(nsMnt)
  remountSys()

proc restoreNamespace(data: NsRestoreData) =
  restoreNs(nsNet, data.netFd)
  restoreNs(nsMnt, data.mntFd)
  setCurrentDir(data.path)

var currentNs {.threadvar.}: string

template inNamespace*(namespaceName: NamespaceName, body: stmt): stmt {.immediate.} =
  if currentNs == nil:
    currentNs = "root"

  let doEnter: bool = namespaceName != currentNs
  let prevNs = currentNs
  var restoreData: NsRestoreData
  if doEnter:
    restoreData = saveNamespace()

  try:
    if doEnter:
      currentNs = namespaceName
      enterNamespace(namespaceName)
    body
  finally:
    if doEnter:
      currentNs = prevNs
      restoreNamespace(restoreData)

proc readSysfsProperty*(ifaceName: InterfaceName, propertyName: string): string =
  inNamespace ifaceName.namespace:
    return readFileSysfs("/sys/class/net" / ifaceName.name / propertyName)

proc writeSysfsProperty*(ifaceName: InterfaceName, propertyName: string, data: string) =
  inNamespace ifaceName.namespace:
    writeFile("/sys/class/net" / ifaceName.name / propertyName, data)

proc listSysfsInterfacesInNs*(namespaceName: NamespaceName): seq[InterfaceName] =
  result = @[]
  inNamespace namespaceName:
    for kind, path in walkDir("/sys/class/net"):
      let name = path.splitPath().tail
      result.add((namespaceName, name))

iterator listNamespaces*(): NamespaceName =
  for kind, path in walkDir("/var/run/netns"):
    let name = path.splitPath().tail
    if name != nil:
      yield name
    else:
      assert false

iterator listSysfsInterfaces*(): InterfaceName =
  # TODO: also walk other namespaces
  for namespace in listNamespaces():
    for iface in listSysfsInterfacesInNs(namespace):
      yield iface

proc sanitizeIfaceName(name: string): string =
  if name == nil:
    raise newException(ValueError, "nil")
  if "/" in name:
    raise newException(ValueError, "invalid argument %1" % [$name])
  return name

proc getMasterName*(interfaceName: InterfaceName): string =
  inNamespace interfaceName.namespace:
    let basePath = "/sys/class/net/" & sanitizeIfaceName(interfaceName.name) & "/brport"

    if not basePath.dirExists:
      return nil

    let brpath = readlink(basePath & "/bridge")
    return brpath.splitPath().tail

proc linkExists*(interfaceName: InterfaceName): bool =
  inNamespace interfaceName.namespace:
    return dirExists("/sys/class/net/" & sanitizeIfaceName(interfaceName.name))

proc callIp*(namespaceName: NamespaceName, args: openarray[string]) =
  inNamespace namespaceName:
    stdout.write "($1) " % namespaceName
    checkCall(args, echo=true)

proc sanitizeArg(val: string): string =
  if val == nil:
    raise newException(ValueError, "nil passed to iproute2 call")
  if val.startsWith("-"):
    raise newException(ValueError, "invalid argument %1" % [$val])
  val

proc namespaceName(name: string): string =
  if name == nil:
    return "root"
  else:
    return name

# Direct

proc ipLinkDel*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "link", "del", "dev", sanitizeArg(ifaceName.name)])

proc ipLinkSet*(ifaceName: InterfaceName, attrs: Table[string, string]) =
  var cmd = @["ip", "link", "set", "dev", sanitizeArg(ifaceName.name)]
  for k, v in attrs:
    cmd.add(k)
    if v != nil:
      cmd.add(sanitizeArg(v))
  callIp(ifaceName.namespace, cmd)

proc ipLinkSet*(ifaceName: InterfaceName, attrs: openarray[(string, string)]) =
  ipLinkSet(ifaceName, attrs.toTable)

proc ipLinkUp*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "link", "set", "dev", sanitizeArg(ifaceName.name), "up"])

proc ipLinkAdd*(ifaceName: InterfaceName, typ: string) =
  callIp(ifaceName.namespace, ["ip", "link", "add", "dev", sanitizeArg(ifaceName.name), "type", "bridge"])

proc ipLinkAddVeth*(namespaceName: NamespaceName, leftName: string, rightName: string) =
  callIp(namespaceName, ["ip", "link", "add", "dev", sanitizeArg(leftName), "type", "veth", "peer", "name", rightName])

proc ipAddrFlush*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "addr", "flush", "dev", sanitizeArg(ifaceName.name)])

proc ipAddrAdd*(ifaceName: InterfaceName, address: string, peerAddress: string = nil) =
  var cmd = @["ip", "addr", "add", "dev", sanitizeArg(ifaceName.name), sanitizeArg(address)]
  if peerAddress != nil:
    cmd &= @["peer", sanitizeArg(peerAddress)]
  callIp(ifaceName.namespace, cmd)

proc ipRouteAddDefault*(namespace: NamespaceName, via: string) =
  # FIXME: what about namespace?
  callIp(namespace, ["ip", "route", "add", "default", "via", sanitizeArg(via)])

proc ipNetnsCreate*(name: string) =
  callIp(RootNamespace, ["ip", "netns", "add", sanitizeArg(name)])

proc ipTunTapAdd*(ifaceName: InterfaceName, mode="tun") =
  callIp(ifaceName.namespace, ["ip", "tuntap", "add", "dev", sanitizeArg(ifaceName.name), "mode", sanitizeArg(mode)])

proc createRootNamespace*() =
  let nsFile = "/var/run/netns/root"
  writeFile(nsFile, "")
  checkCall(["mount", "--bind", "/proc/self/ns/net", nsFile], echo=true)

# "High-level"

proc rename*(ifaceName: InterfaceName, name: string, namespace: string) =
  var attrs = initTable[string, string]()
  if name != nil:
    attrs["name"] = name

  attrs["netns"] = namespaceName(namespace)

  ipLinkSet(ifaceName, attrs)
