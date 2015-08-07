# iproute2 cheatsheet: http://baturin.org/docs/iproute2
# netlink overview: http://1984.lsi.us.es/~pablo/docs/spae.pdf
import os, osproc
import subprocess, commonnim

type InterfaceName* = tuple[namespace: string, name: string]

proc readSysfsProperty*(ifaceName: InterfaceName, propertyName: string): string =
  readFileSysfs("/sys/class/net" / ifaceName.name / propertyName)

proc writeSysfsProperty*(ifaceName: InterfaceName, propertyName: string, data: string) =
  writeFile("/sys/class/net" / ifaceName.name / propertyName, data)

iterator listSysfsInterfaces*(): InterfaceName =
  # TODO: also walk other namespaces
  for kind, path in walkDir("/sys/class/net"):
    let name = path.splitPath().tail
    yield (nil, name)

proc delete*(ifaceName: InterfaceName) =
  checkCall(["ip", "link", "del", "dev", ifaceName.name], echo=true)
