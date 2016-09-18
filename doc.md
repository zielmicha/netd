
# Basic link setup

The basic syntax for configuring network links is:

```
link_defintion {
    link_configuration; # addresses, sublinks etc
};
```

The following example configures address 10.9.0.1 on hardware device eth0.

```
link dev eth0 {
    static { address 10.9.0.1/24; };
};
```

# Link addressing

## Static addressing

## DHCP addressing

# Wireless setup

```
# use device named wlan0
link dev wlan0 {
    # Configure AP on device wlan0
    wireless_ap default {
        ssid mynet1; # network name
        keymgmt wpa2_psk; # network security
        passphrase HelloWorld99; # network passphrase

        static { # configure IP address (and route)
            address 10.9.0.1/24;
        };

        dhcp_server { # configure DHCP server
            addresses 10.9.0.10 10.9.0.200;
            subnet 24;
            nameserver 8.8.8.8;
            router 10.9.0.1;
        };
    };
    # Configure other AP on device wlan0.f
    # Multiple access points are not supported on all network cards.
    wireless_ap f {
        ssid mynet2;
        keymgmt none; # open network
        share_internet 10.10.0.0/24; # shortcut for static address, dhcp server and iptables MASQUERADE
    };
};
```

# DBUS interface

## Loading fragments

```
dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Fragments.LoadFragment 'string:myfragment' "string:$(cat myfragment.conf)"
dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Core.Reload
```
