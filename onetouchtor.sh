#!/bin/bash
#Purpose: Automate Tor Hidden Service Generation
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

# Get started prompts
TOR_HS=/var/lib/tor/$hsdir
read -p "Lets setup a hidden service, shall we? [Press Enter to cont]"
# Hidden Servide Directory creation
while [ "$confirm_hs" != "Confirmed" ]; do
	echo -e "\n\nDesired name of the HiddenService directory"
	read -p "[example: monero] " hsdir
        echo -e "You entered: $hsdir\n"
	read -p "Is this correct? [y/N]: " confirm
	confirm_hs=$(
	case "$confirm" in
        y|Y) echo -e "Confirmed";;
	*) echo -e "Try again!\n\n";;
	esac)
done
# Hidden Servide internal port assign
while [ "$confirm_port" != "Confirmed" ]; do
	echo -e "\n\nWhat port is your service running on?"
	read -p "[example: 18089] " localport
        echo -e "You entered: $localport\n"
	read -p "Is this correct? [y/N]: " confirm
	confirm_port=$(
	case "$confirm" in
        y|Y) echo -e "Confirmed";;
	*) echo -e "Try again!\n\n";;
	esac)
done
# Hidden Servide external port assign
while [ "$confirm_extport" != "Confirmed" ]; do
	echo -e "\n\nEnter the port for the onion"
	read -p "[example: 18089] " onionport
        echo -e "You entered: $onionport\n"
	read -p "Is this correct? [y/N]: " confirm
	confirm_extport=$(
	case "$confirm" in
        y|Y) echo -e "Confirmed";;
	*) echo -e "Try again!\n\n";;
	esac)
done
# Read Values
echo -e "HiddenServiceDir $TOR_HS"
echo -e "HiddenServicePort $onionport 127.0.0.1:$localport"
read -p "Does this look good? [y/N]" abort
	case $abort in
		y|Y) echo "good";;
		*) echo "abort";;
	esac
if [ $abort = "abort" ]; then
exit 0
fi
printf "$confirm_hs"

# Step 1: Install Tor
echo "Installing Tor..."
apt install tor -y

# Step 2: Edit torrc file
cp /etc/tor/torrc /etc/tor/torrc.old
# Check if already configured
# -E, --extended-regexp : Interpret PATTERNS as extended regular expressions
HS=$(grep -E [$hsport]{5}$ /etc/tor/torrc)
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
\nHiddenServicePort $onionport 127.0.0.1:$localport\n|" /etc/tor/torrc
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

footer="Your Onion address is: $ONION"
COLUMNS=$(tput cols)
title_size=${#footer}
# Note $ is not needed before numeric variables
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "*"
printf "%${span}s\n" "$footer"
printf "%${COLUMNS}s" " " | tr " " "*"


sed -i s"/\$ONION/$ONION/" .btcpayserver/Main/settings.config
