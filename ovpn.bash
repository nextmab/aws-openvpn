#!/bin/bash

echo "All rights reserved to Nextmab"
sleep 3
clear
echo "This script is for ubuntu 16.4."
if  [[ !  -e /etc/debian_version ]]; then
        echo "Not an ubuntu server. "
        exit
fi

if [[ -e /etc/openvpn/server.conf ]]; then
	while :
	do
	clear
		echo "OpenVPN is already installed."
		echo
		echo "What do you want to do?"
		echo "   1) Add a new user"
		echo "   2) Remove client access"
		echo "   3) Exit"
		read -p "Select an option [1-3]: " option
		case $option in
			1)
			echo ""
			read -p "Client name: " name2

			cd ~/openvpn-ca
			source vars
			./build-key --batch $name2
			cd ~/client-configs
			./make_config.sh $name2
			clear
			echo "The client is on: ~/client-configs/files/ "
			ls -l ~/client-configs/files/ | grep $name2 
			echo ""
			echo "copy all the text to C:\Program Files\OpenVPN\config\ " $name2".ovpn"
			echo  ""
			echo  "in 10 sec it will be ready to copy. "
			sleep 10
			cat ~/client-configs/files/$name2.ovpn
            exit;;
			2)
			cd ~/openvpn-ca
			source vars
			echo ""
			ls -l ~/client-configs/files/
			read -p "Client to remove: " name3
			./revoke-full $name3
			sudo cp ~/openvpn-ca/keys/crl.pem /etc/openvpn
			sudo systemctl start openvpn@server
			echo""
			echo "This error is ok it means revoking is DONE "
			exit;;
			3) 
			exit;;
		esac
	done
fi			

echo "Don't forget to disable the source/dest check on aws. "
sleep 5
iname=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')
echo ""
read -p "Client name: " name
clear
echo ""
echo "# These are the default values for fields
# which will be placed in the certificate.
# Don't leave any of these fields blank.

export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="Fort-Funston"
export KEY_EMAIL="me@myhost.mydomain"
export KEY_OU="MyOrganizationalUnit""
echo ""
read -p "Use Vars defaults? y/n " answer
echo ""
sudo apt-get update -y
sudo apt-get install openvpn easy-rsa expect -y

sudo /etc/init.d/apparmor stop
sudo update-rc.d -f apparmor remove
make-cadir ~/openvpn-ca

cd ~/openvpn-ca

cp vars vars.B




if [ "$answer" = "n" ]; then
		clear
		echo ""
		echo "# These are the default values for fields
		# which will be placed in the certificate.
		# Don't leave any of these fields blank.

		export KEY_COUNTRY="US"
		export KEY_PROVINCE="CA"
		export KEY_CITY="SanFrancisco"
		export KEY_ORG="Fort-Funston"
		export KEY_EMAIL="me@myhost.mydomain"
		export KEY_OU="MyOrganizationalUnit""
		echo ""
		echo " Please fill the form as you like. "
				

        read -p "KEY_COUNTRY=" KEY_COUNTRY
        sed -i "64s/.*/export KEY_COUNTRY=\"$KEY_COUNTRY\"/" vars
        read -p "KEY_PROVINCE=" KEY_PROVINCE
        sed -i "65s/.*/export KEY_PROVINCE=\"$KEY_PROVINCE\"/" vars
        read -p "KEY_CITY=" KEY_CITY
        sed -i "66s/.*/export KEY_CITY=\"$KEY_CITY\"/" vars
        read -p "KEY_ORG=" KEY_ORG
        sed -i "67s/.*/export KEY_ORG=\"$KEY_ORG\"/" vars
        read -p "KEY_EMAIL=" KEY_EMAIL
        sed -i "68s/.*/export KEY_EMAIL=\"$KEY_EMAIL\"/" vars
        read -p "KEY_OU=" KEY_OU
        sed -i "69s/.*/export KEY_OU=\"$KEY_OU\"/" vars
fi




sed -i '72s/.*/export KEY_NAME="server"/' vars


source vars
./clean-all

./build-ca --batch

./build-key-server --batch server
clear

sh ./build-dh

openvpn --genkey --secret keys/ta.key




#client


cd ~/openvpn-ca
source vars

./build-key --batch $name


cd ~/openvpn-ca/keys
sudo cp ca.crt server.crt server.key ta.key dh2048.pem /etc/openvpn

gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf

#Adjust the OpenVPN Configuration




sudo sed -i '32s/.*/port 443/' /etc/openvpn/server.conf
sudo sed -i '35s/.*/proto tcp/' /etc/openvpn/server.conf
sudo sed -i '36s/.*/;proto udp/' /etc/openvpn/server.conf
sudo sed -i '192s/.*/push "redirect-gateway def1 bypass-dhcp"/' /etc/openvpn/server.conf
sudo sed -i '200s/.*/push "dhcp-option DNS 208.67.222.222"/' /etc/openvpn/server.conf
sudo sed -i '201s/.*/push "dhcp-option DNS 208.67.220.220"/' /etc/openvpn/server.conf
sudo sed -i '244s/.*/tls-auth ta.key 0/' /etc/openvpn/server.conf
sudo sed -i '245i\key-direction 0' /etc/openvpn/server.conf
sudo sed -i '250s/.*/cipher AES-128-CBC/' /etc/openvpn/server.conf
sudo sed -i '251i\auth SHA256' /etc/openvpn/server.conf
echo 'crl-verify crl.pem' | sudo tee --append /etc/openvpn/server.conf



#Adjust the Server Networking Configuration
#Allow IP Forwarding

sudo sed -i '28s/.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p


sudo sed -i '10i\# START OPENVPN RULES' /etc/ufw/before.rules
sudo sed -i '11i\# NAT table rules' /etc/ufw/before.rules
sudo sed -i '12i\*nat' /etc/ufw/before.rules
sudo sed -i '13i\:POSTROUTING ACCEPT [0:0]' /etc/ufw/before.rules
sudo sed -i '14i\# Allow traffic from OpenVPN client to eth0 (change to the interface you discovered!)
' /etc/ufw/before.rules
netstring="-A POSTROUTING -s 10.8.0.0/8 -o $iname -j MASQUERADE"
#sudo sed -i "15i\-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
#" /etc/ufw/before.rules
echo $netstring | sudo sed -i '13r /dev/stdin' /etc/ufw/before.rules
sudo sed -i '16i\COMMIT' /etc/ufw/before.rules
sudo sed -i '17i\# END OPENVPN RULES' /etc/ufw/before.rules



sudo sed -i '19s/.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw



sudo ufw allow 443/tcp
sudo ufw allow OpenSSH



sudo ufw disable




echo '#!/usr/bin/expect -f


set timeout -1

spawn ufw enable

expect "Command may disrupt existing ssh connections. Proceed with operation"
send -- "y\r"
expect eof'> enable_ufw.exp
chmod +x enable_ufw.exp
sudo ./enable_ufw.exp

sudo systemctl start openvpn@server


sudo systemctl enable openvpn@server

mkdir -p ~/client-configs/files


chmod 700 ~/client-configs/files

cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf

PUBLICIP=$(curl https://ipinfo.io/ip)
IP=$PUBLICIP
PORT=443

sed -i '36s/.*/proto tcp/' ~/client-configs/base.conf
sed -i '37s/.*/;proto udp/' ~/client-configs/base.conf
sed -i "42s/.*/remote $IP $PORT/" ~/client-configs/base.conf

sed -i '88,90 s/^/#/' ~/client-configs/base.conf

sed -i '88i\cipher AES-128-CBC' ~/client-configs/base.conf
sed -i '89i\auth SHA256' ~/client-configs/base.conf
sed -i '90i\key-direction 1' ~/client-configs/base.conf
sed -i '91i\#script-security 2' ~/client-configs/base.conf
sed -i '92i\#up /etc/openvpn/update-resolv-conf' ~/client-configs/base.conf
sed -i '93i\#down /etc/openvpn/update-resolv-conf' ~/client-configs/base.conf


cat > ~/client-configs/make_config.sh <<'endmsg'
#!/bin/bash

# First argument: Client identifier

KEY_DIR=~/openvpn-ca/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}.ovpn

endmsg


chmod 700 ~/client-configs/make_config.sh

cd ~/client-configs
./make_config.sh $name

clear
echo "The client is on: ~/client-configs/files/ "
ls -l ~/client-configs/files/ | grep $name
echo ""
echo "copy all the text to C:\Program Files\OpenVPN\config\ " $name".ovpn"
echo  ""
echo  "in 20 sec it will be ready to copy. "
echo  ""
echo  "open port 443/tcp in the security group. "

sleep 20

cat ~/client-configs/files/$name.ovpn