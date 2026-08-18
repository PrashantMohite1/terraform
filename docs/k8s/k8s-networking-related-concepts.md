



## Common File systems


| OS      | Common filesystem | Example               |
| ------- | ----------------- | --------------------- |
| Windows | **NTFS**          | `C:\`, `D:\`          |
| Windows | exFAT             | USB drives            |
| Windows | FAT32             | Older USB/SD cards    |
| Linux   | **ext4**          | Common Linux disk     |
| Linux   | XFS               | Servers               |
| Linux   | Btrfs             | Some Linux systems    |
| Linux   | OverlayFS         | Containers            |
| Linux   | tmpfs             | RAM-backed filesystem |

containers use overlay file system that why we need overlay filesystem loaded in kernel for k8s pods and its container.

command to load overlayfs and br_netfilter
```
    modprobe overlay
    modprobe br_netfilter
```



### br_netfilter
Linux has a networking framework called Netfilter. Netfilter provides hooks that allow the Linux networking stack to inspect, filter, modify, and perform NAT on packets. Tools such as iptables and nftables interact with Netfilter.

A Linux bridge normally forwards Ethernet frames at Layer 2 based on MAC addresses. Bridged traffic does not normally go through the IPv4/IPv6 routing Netfilter hooks.

br_netfilter is a kernel module that allows bridged IPv4/IPv6 traffic to also be passed through the IPv4/IPv6 Netfilter hooks, so that iptables rules can see and process that bridged traffic.


### Why does it br_netfilter required for k8s?

Kubernetes itself doesn't provide the complete pod networking implementation.
A CNI network plugin does that.Many Kubernetes networking configurations need bridged traffic to be visible to Netfilter/iptables. That's why we use br_netfilter for k8s 

Kubernetes networking and its networking components may need packet-processing mechanisms such as: iptable, nftable, connection tracking, NAT, filtering.
So Kubernetes needs bridged traffic to be handled correctly by Netfilter.   and that bridge and netfilter connection is provided by br_netfilter module thats why load this module 


### Why we dont need to load br_netfilter for docker?
Docker's networking works without you explicitly configuring br_netfilter. Docker creates its bridge networks and firewall/NAT rules itself.
Docker itself manages the networking and creates the required iptables rules for its bridge networks.



### sysctl

sysctl is a command-line utility and system call in Linux (and other Unix-like systems) used to read and modify kernel parameters at runtime.



```
┌─────────────────────────────────────────────┐
│              Kubernetes Node                │
│                                             │
│   Pod                                       │
│    │                                        │
│    ▼                                        │
│   veth                                      │
│    │                                        │
│    ▼                                        │
│ Linux bridge / networking                   │
│    │                                        │
│    ├──── IPv4 ──► br_netfilter ──► iptables │
│    │                                        │
│    └──── IPv6 ──► br_netfilter ──► ip6tables│
│                                             │
│                     │                       │
│                     ▼                       │
│              IP forwarding                  │
│                     │                       │
│                     ▼                       │
│               Other network                 │
└─────────────────────────────────────────────┘

```

| Setting                      | Simple meaning                                             |
| ---------------------------- | ---------------------------------------------------------- |
| `bridge-nf-call-iptables=1`  | Let bridged **IPv4** traffic be seen by iptables           |
| `bridge-nf-call-ip6tables=1` | Let bridged **IPv6** traffic be seen by ip6tables          |
| `ip_forward=1`               | Allow Linux to **forward IPv4 packets between interfaces** |


so above kernel parameter we set using sysctl - 0 = disabled, 1 = enabled