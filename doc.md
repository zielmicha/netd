
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

You can also rename interfaces using `name` option.

```
link dev ens0 {
    name eth0;
    static { address 10.9.0.1/24; };
};
```

Note that in `link dev` command you always need to specify the original interface name (given by udev or kernel, `ens0` in this case), not the target name (`eth0` in this case).

# Network namespaces

Use bare `namespace XXX;` command to declare that network namespace named `XXX` is managed by netd.

```
namespace mynet;
```

Then you can add `namespace XXX;` declaration to link, for example:

```
link dev eth0 {
    namespace mynet; # move interface eth0 to network namespace mynet
    static { address 10.9.0.1/24; };
};
```

## Network/User namespaces interactions

*Security Warning*: don't ask netd to manage network namespaces having different owning user namespaces. `root` in the the child user namespace could use that to manipulate network traffic in parent user namespace.

# Link addressing

## Static addressing

Example

```
link dev eth0 {
    # Configure address and the default gateway.
    static {
        address 10.9.0.15/24;
        default_route 10.19.0.1;
    };

    # Configure another address on the same interface
    static {
        address 10.10.0.1/24;
    };
};
```

All options:

```
static {
    address ip/mask; # IP address and subnet mask (required)
    default_route ip; # IP of defautl route (optional)
    peer_address ip/mask; # peer IP address in case of point-to-point links (optional)
};
```

## DHCP addressing

Obtaining address using DHCP is straightforward:

```
link dev eth0 {
    dhcp {};
};
```

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
    # Configure other AP on device mywlan
    # Multiple access points are not supported on all network cards.
    wireless_ap foo {
        name mywlan; # change device name, default would be wlan0.vif-foo
        ssid mynet2;
        keymgmt none; # open network
        share_internet 10.10.0.0/24; # shortcut for static address, dhcp server and iptables MASQUERADE
    };
};
```

# DBUS interface

## Loading fragments

netd allows loading of configuration fragments in runtime. This is useful for apps that need to apply programatically generated configuration.

Example:

```
dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Fragments.LoadFragment 'string:myfragment' "string:bridge mybr0 { port eth0; };"
dbus-send --print-reply --type=method_call --system /net/networkos/netd --dest=net.networkos.netd net.networkos.netd.Core.Reload
```
