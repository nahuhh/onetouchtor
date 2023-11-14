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
read -p "Lets setup a hidden service, shall we? [Press Enter to cont]"
if [ "$USER" != "root" ]; then
echo -e "\n\nRTFM asshole. This script must be run as root.\nYou'll need to run \"sudo su\" first, please and thanks."
exit 0
fi
until [ "$proceed" = "Good" ]; do
	# Hidden Servide Directory assign
	echo -e "\n\nDesired name for the HiddenService directory"
	read -p "[example: monero] " hsdir
	echo -e "\nEnter the port for the .onion domain"
	read -p "[example: 18089] " onionport
	echo -e "\nEnter the local port that your service"
	read -p "[example: 18089] " localport
	# Read Values
	TOR_HS=/var/lib/tor/$hsdir
	torrcinput="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport 127.0.0.1:$localport\n"
	# Do we add services to the onion?
	read -p "Would you like to add another service to this Onion? [y/N]" addservice
	additional=$(
		case $addservice in
			y|Y) echo "add";;
			*) echo "finished";;
		esac)
		if [ "$additional" = "add" ]; then
			echo -e "\nEnter the port for the .onion domain"
			read -p "[example: 18084] " onionport2
        		echo -e "\nEnter the local port that your service"
			read -p "[example: 18084] " localport2
			# Confirm all details
			torrcinput="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport 127.0.0.1:$localport\nHiddenServicePort $onionport2 127.0.0.1:$localport2\n"
		fi
	echo -e "$torrcinput"
	read -p "Does this look good? [y/N] " abort
	proceed=$(
		case $abort in
			y|Y) echo -e "Good";;
			*) echo "Try again" && confirm_port= && confirm_extport= && confirm_hs= ;;
		esac)
	printf "$proceed\n\n"
done

# Step 1: Install Tor
torinstall=$(apt-cache policy tor | grep "Installed:" | grep -E -o "[0-9]\w+")
if [  "$torinstall" ]; then
	echo "Tor is already installed"
else
	echo "Installing Tor..."
	sleep 1
	apt install tor -y
fi

# Step 2: Edit torrc file
cp /etc/tor/torrc /etc/tor/torrc.old
# Check if already configured
# -E, --extended-regexp : Interpret PATTERNS as extended regular expressions
HSDIR=$(grep -E $TOR_HS /etc/tor/torrc)
ONIONPORT=$(grep -E $onionport /etc/tor/torrc)
LOCALPORT=$(grep -E $localport /etc/tor/torrc)
if [[ -n "$ONIONPORT" && -n "$LOCALPORT" && -n "$HSDIR" ]]; then
	printf "\n\n$HSDIR\n$LOCALPORT\n\nAbove Hidden Service files already exist, so skipping\n\n"
	sleep 2
else
# Step 3: Create HiddenService dir within /var/lib/tor and change both permissions and ownership
        echo "Creating $hsdir HiddenService directory..."
        mkdir $TOR_HS
        chmod 700 $TOR_HS
        chown -R debian-tor:debian-tor $TOR_HS
	echo "Editing torrc file..."
	sed -i -z s"|#HiddenServicePort 22 127.0.0.1:22\n|#HiddenServicePort 22 127.0.0.1:22\n\n# $hsdir Hidden Service$torrcinput|" /etc/tor/torrc
fi

#Step 4: Start Tor to generate hostname (onion address) in /var/lib/tor/
if ! [ -e $TOR_HS/hostname ]; then
        echo "Please wait while Tor restarts to generate your HiddenService"
        systemctl restart tor
	until [ -e $TOR_HS/hostname ]; do
		echo "Refreshing in 5s (this shouldnt take longer than 30s..)"
		sleep 5
	done
fi

ONION=`cat $TOR_HS/hostname`
footer="Your Onion address is: $ONION"
COLUMNS=$(tput cols)
title_size=${#footer}
# Note $ is not needed before numeric variables
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "*"
printf "%${span}s\n" "$footer"
printf "%${COLUMNS}s" " " | tr " " "*"

sed -i s"/\$ONION/$ONION/" .btcpayserver/Main/settings.config
