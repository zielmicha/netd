#!/bin/sh
set -e
./build.sh
rm -r build/deb || true
p=build/deb/netd
mkdir -p $p/DEBIAN $p/usr/local/bin $p/etc/dbus-1/system.d $p/lib/systemd/system

install bin/netd $p/usr/local/bin/
install -m644 net.networkos.netd.conf $p/etc/dbus-1/system.d/
install netd.service $p/lib/systemd/system/

VERSION="0.1.2"

cat > $p/DEBIAN/control <<EOF
Package: netd
Version: $VERSION
Depends: libdbus-1-3, iptables, iproute2, busybox | busybox-static
Recommends: iw, hostapd, wpasupplicant
Section: custom
Priority: optional
Architecture: $(dpkg --print-architecture)
Essential: no
Installed-Size: 1024
Maintainer: Michal Zielinski <michal@zielinscy.org.pl>
Description: Advanced network manager for Linux desktops, servers and embedded systems.
EOF

cd build/deb
fakeroot dpkg-deb --build netd
mv netd.deb netd-$VERSION-$(dpkg --print-architecture).deb
