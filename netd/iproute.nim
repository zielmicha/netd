# iproute2 cheatsheet: http://baturin.org/docs/iproute2
# netlink overview: http://1984.lsi.us.es/~pablo/docs/spae.pdf
import os

proc readSysfsProperty*(ifaceName: string, propertyName: string): string =
  readFile("/sys/class/net" / ifaceName / propertyName)

proc writeSysfsProperty*(ifaceName: string, propertyName: string, data: string) =
  writeFile("/sys/class/net" / ifaceName / propertyName, data)

iterator listSysfsInterfaces*(): string =
  for kind, path in walkDir("/sys/class/net"):
    let name = path.splitPath().tail
    yield name
