#!/bin/bash
install bin/netd /usr/local/bin
install -m644 net.networkos.netd.conf /etc/dbus-1/system.d
install netd.service /etc/systemd/system/
systemctl enable netd
