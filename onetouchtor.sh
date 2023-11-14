#!/bin/bash
#Purpose: Automate XMR Tor Hidden Service
# START #
# Title Bar
title="Tor Hidden Service Configurator"
COLUMNS=$(tput cols)
title_size=${#title}
# Note $ is not needed before numeric variables
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "*"
printf "%${span}s\n" "$title"
printf "%${COLUMNS}s" " " | tr " " "*"

# Get started
read -p "Lets setup a hidden service, shall we? [Press Enter]"
# Hidden Servide Directory creation
while [ "$confirm_hs" != "Confirmed" ]; do
	echo -e "\n\nDesired name of the HiddenService directory"
	read -p "[example: monero] " hsdir
        echo "You entered: $hsdir"
	read -p "Is this correct? [y/N]: " confirm
	confirm_hs=$(
	case "$confirm" in
        y|Y) echo -e "Confirmed";;
	*) echo -e "Try again!\n\n";;
	esac)
done
printf "\n$confirm_hs\n\n"
TOR_HS=/var/lib/tor/$hsdir

# Step 1: Install Tor
echo "Installing Tor..."
apt install tor -y

# Step 2: Edit torrc file
cp /etc/tor/torrc /etc/tor/torrc."$DATE"
# -E, --extended-regexp : Interpret PATTERNS as extended regular expressions
HS=$(grep -E [0123]{5}$ /etc/tor/torrc)
HSDIR=$(grep -E $hsdir /etc/tor/torrc)
if [[ -n "$HS" && -n "$HSDIR" ]]; then
	printf "\n\n$HSDIR\n$HS\n\nAbove Hidden Service files already exist, so skipping\n\n"
else
# Step 3: Create HiddenService dir within /var/lib/tor and change both permissions and ownership
        echo "Creating $hsdir HiddenService directory..."
        mkdir $TOR_HS
        chmod 700 $TOR_HS
        chown -R debian-tor:debian-tor $TOR_HS
	echo "Editing torrc file..."
	sed -i -z \
s"|#HiddenServicePort 22 127.0.0.1:22\
\n|#HiddenServicePort 22 127.0.0.1:22\n\
\n# $hsdir Hidden Service\
\nHiddenServiceDir $TOR_HS\
\nHiddenServicePort 80 127.0.2.1:23001\n|" /etc/tor/torrc
fi

#Step 4: Start Tor to generate hostname (onion address) in /var/lib/tor/
ONION=`cat $TOR_HS/hostname`
if ! [ -e $TOR_HS/hostname ]; then
        echo "Please wait while Tor restarts to generate your HiddenService"
        systemctl restart tor
        sleep 7
        echo "Copying hostname..."
        sleep 2
fi
echo -e "\n\nYour Onion address is $ONION\n\n"
sed -i s"/\$ONION/$ONION/" .btcpayserver/Main/settings.config
