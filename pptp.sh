#!/bin/bash
# Interactive PoPToP install script for an OpenVZ VPS wtih IPtables

echo "######################################################"
echo "Interactive PoPToP Install Script for an OpenVZ VPS"
echo
echo "Make sure to contact your provider and have them enable"
echo "IPtables and ppp modules prior to setting up PoPToP."
echo "PPP can also be enabled from SolusVM."
echo
echo "You need to set up the server before creating more users."
echo "A separate user is required per connection or machine."
echo "######################################################"
echo
echo
echo "Select on option:"
echo "1) Set up new PoPToP server AND create one user"
echo "2) Create additional users"
read x
if test $x -eq 1; then
	echo "Enter username that you want to create (eg. client1 or john):"
	read u
	echo "Specify password that you want the server to use:"
	read p

# get the VPS IP
ip=`ifconfig venet0:0 | grep 'inet addr' | awk {'print $2'} | sed s/.*://`

echo
echo "Downloading and Installing"
apt-get update
apt-get -y install pptpd


echo
echo "Creating Server Config"
cat > /etc/ppp/pptpd-options <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
nodefaultroute
lock
nobsdcomp
END

# setting up pptpd.conf
echo "option /etc/ppp/pptpd-options" > /etc/pptpd.conf
echo "logwtmp" >> /etc/pptpd.conf
echo "localip $ip" >> /etc/pptpd.conf
echo "remoteip 10.1.0.1-100" >> /etc/pptpd.conf

# adding new user
echo "$u	*	$p	*" >> /etc/ppp/chap-secrets

echo
echo "Forwarding IPv4 and Enabling it on boot"
cat >> /etc/sysctl.conf <<END
net.ipv4.ip_forward=1
END
sysctl -p

echo
echo "Updating IPtables Routing and Enabling it on boot"
iptables -t nat -A POSTROUTING -j SNAT --to $ip

#vpn iptables
iptables -A TCP -p tcp --dport 1194 -j ACCEPT
iptables -A TCP -p udp --dport 1194 -j ACCEPT
iptables -N fw-interfaces

### Setting up the nat table
## Setting up the POSTROUTING chain
iptables -A fw-interfaces -i tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE


## Save settings
#/sbin/service iptables save
iptables-save -c > /etc/iptables/iptables.rules



# saves iptables routing rules and enables them on-boot
iptables-save > /etc/iptables.conf


chmod +x /etc/network/if-pre-up.d/iptables
cat >> /etc/ppp/ip-up <<END
ifconfig ppp0 mtu 1400
END

echo
echo "Restarting"
sleep 5
/etc/init.d/pptpd restart

echo
echo "Server setup complete!"
echo "Connect to your VPS at $ip with these credentials:"
echo "Username:$u ##### Password: $p"

# runs this if option 2 is selected
elif test $x -eq 2; then
	echo "Enter username that you want to create (eg. client1 or john):"
	read u
	echo "Specify password that you want the server to use:"
	read p

# get the VPS IP
ip=`ifconfig venet0:0 | grep 'inet addr' | awk {'print $2'} | sed s/.*://`

# adding new user
echo "$u	*	$p	*" >> /etc/ppp/chap-secrets

echo
echo "Addtional user added!"
echo "Connect to your VPS at $ip with these credentials:"
echo "Username:$u ##### Password: $p"

else
echo "Invalid selection, quitting."
exit
fi
