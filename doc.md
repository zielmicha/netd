
# DBUS interface

## Loading fragments

dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Fragments.LoadFragment 'string:myfragment' "string:$(cat myfragment.conf)"
dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Core.Reload
