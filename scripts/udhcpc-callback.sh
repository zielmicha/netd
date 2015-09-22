#!/bin/sh
dbus-send --print-reply --type=method_call --system --dest=net.networkos.netd /net/networkos/netd \
          net.networkos.netd.DhcpClient.Callback \
          string:"$abstractName" \
          string:"$1" \
          string:"$ip" \
          string:"$subnet" \
          string:"$router"
