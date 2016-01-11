[Package]
name          = "netd"
version       = "0.0.1"
author        = "Michał Zieliński <michal@zielinscy.org.pl>"
description   = "netd is an advanced network manager for Linux desktops and servers"
license       = "MIT"
skipExt       = "nim"
binDir        = "bin"
bin           = "netd"

[Deps]
Requires: "nim >= 0.11.2"
Requires: "dbus >= 0.0.1"
