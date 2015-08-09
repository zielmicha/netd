# iproute2 cheatsheet: http://baturin.org/docs/iproute2
# netlink overview: http://1984.lsi.us.es/~pablo/docs/spae.pdf
import os, osproc, tables, strutils, posix
import subprocess, commonnim

type
  ## Location of a kernel interface.
  InterfaceName* = tuple[namespace: string, name: string]

proc readSysfsProperty*(ifaceName: InterfaceName, propertyName: string): string =
  readFileSysfs("/sys/class/net" / ifaceName.name / propertyName)

proc writeSysfsProperty*(ifaceName: InterfaceName, propertyName: string, data: string) =
  writeFile("/sys/class/net" / ifaceName.name / propertyName, data)

template inNamespace(namespaceName: string): stmt =
  assert namespaceName == nil

iterator listSysfsInterfacesInNs*(namespaceName: string): InterfaceName =
  # TODO: also walk other namespaces
  inNamespace namespaceName
  for kind, path in walkDir("/sys/class/net"):
    let name = path.splitPath().tail
    yield (namespaceName, name)

iterator listSysfsInterfaces*(): InterfaceName =
  for iface in listSysfsInterfacesInNs(nil):
    yield iface

proc readlink(path: string): string =
  var buf: array[512, char]
  if readlink(path, buf, sizeof(buf)) < 0:
    raiseOSError(osLastError())
  return $buf

proc sanitizeIfaceName(name: string): string =
  if name == nil:
    raise newException(ValueError, "nil")
  if "/" in name:
    raise newException(ValueError, "invalid argument %1" % [$name])
  return name

proc getMasterName*(interfaceName: InterfaceName): string =
  inNamespace interfaceName.namespace
  let basePath = "/sys/class/net/" & sanitizeIfaceName(interfaceName.name) & "/brport"

  if not basePath.dirExists:
    return nil

  let brpath = readlink(basePath & "/bridge")
  return brpath.splitPath().tail

proc callIp*(namespaceName: string, args: openarray[string]) =
  assert namespaceName == nil or namespaceName == "root"
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

proc ipAddrFlush*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "addr", "flush", "dev", sanitizeArg(ifaceName.name)])

proc ipAddrAdd*(ifaceName: InterfaceName, address: string) =
  callIp(ifaceName.namespace, ["ip", "addr", "add", "dev", sanitizeArg(ifaceName.name), sanitizeArg(address)])

proc ipRouteAddDefault*(via: string) =
  # FIXME: what about namespace?
  callIp(nil, ["ip", "route", "add", "default", "via", sanitizeArg(via)])

proc ipNetnsCreate*(name: string) =
  callIp(nil, ["ip", "netns", "add", sanitizeArg(name)])

proc createRootNamespace*() =
  let nsFile = "/var/run/netns/root"
  writeFile(nsFile, "")
  checkCall(["mount", "--bind", "/proc/self/ns/net", nsFile], echo=true)

# "High-level"

iterator listNamespaces*(): string =
  for kind, path in walkDir("/var/run/netns"):
    let name = path.splitPath().tail
    yield name

proc rename*(ifaceName: InterfaceName, name: string, namespace: string) =
  var attrs = initTable[string, string]()
  if name != nil:
    attrs["name"] = name

  attrs["netns"] = namespaceName(namespace)

  ipLinkSet(ifaceName, attrs)
