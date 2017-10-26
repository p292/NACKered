## NACKered

NACKered is a small bash script based off the work of Alva Lease 'Skip' Duckwall IV to bypass 802.1x Network Access Control. Tested and working on a raspberrypi running a cut down version of Kali. 

## Hardware Prerequisites

* You'll need a system with two ethernet ports and physical access to place your device inline.
* If you're running this on a box you've dropped into a network and you need to setup a remote connection to it, for example 3G/4G, you'll need to do some minor edits, adding your new interface into the bridge etc.

## Software Prerequisites

Very limited software prerequisites are needed:
* Debian Based OS (with usual tools bash/ipconfig/route etc)
* brctl (bridge control - used to create the bridges)
* macchanger (alters mac addresses)
* mii-tool (forces a reauth by cycling connections)
* tcpdump (packet capture stuff)
* arptables/ebtables/iptables (does rewriting and NAT'ing)
* br_netfilter kernel module needs to be loaded (# modprobe br_netfilter)

## Execution Flow
The script currently has debug breakpoints in it (it does "Press Enter" to do next step), I'll release a fully automatic one at some point.

1. We setup the environment, killing services we don't like, disabling IPv6, removing dns-cache etc
2. We set some variables, obtaining MAC addresses from interfaces etc
    * The BridgeIP is set to 169.254.66.66, the "secret" SSH callback port is set to 2222, the NAT range is set to 61000-62000
3. We kill all connections from the laptop and setup the bridge
4. We do the little kernel trick to forward EAPoL packets. Also enable bridge-nf-call-iptables to allow the bridge to send packets back through iptables.
5. We bring up the legit client and the switch side connection on the bridge - should auth now and be happy.
6. We start packet capturing the traffic running through our device (but we are still dark!)
7. We use arptables/iptables to drop any traffic from our machine
8. A rule is made in ebtables to rewrite all MAC addresses leaving the device to look like the Victim's.
9. A default route is made such that all traffic is sent to our fake gateway, which has the mac of the real gateway (which we only know the mac address of). Because layer 2 is fine it will get to where it needs to go to.
10. Sneaky ssh callback is created victim-ip:2222 will actually SSH into ourmachine:22
11. Rule is made in iptables to rewrite all TCP/UDP/ICMP traffic with Victim-IP
12. SSH server is started on attack machine in case it wasn't
13. Everything should be working so we take off the traffic drops made in line 7, and in theory we can get going, doing what we need to do.

## Built With
Trial & Error + A Computer.

## Contributing
Feel free to submit pull requests.

## Authors
Matt E - KPMG Cyber Defence Services

## License
This project is licensed under the BSD-3-Clause License, see license.md for more info.

## Acknowledgments
* Alva Lease 'Skip' Duckwall IV
* KPMG Cyber Defence Services 2013-Present
* Justin M
