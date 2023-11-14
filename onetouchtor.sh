#!/bin/bash
#Purpose: Automate Tor Hidden Service Generation
# START #
# Colors
cyan="echo -e -n \e[36;1m"
red="echo -e -n \e[31;1m"
green="echo -e -n \e[32;1m"
nocolor="echo -e -n \e[0m"

# Title Bar
$green
title="Tor Hidden Service Configurator"
COLUMNS=$(tput cols)
title_size=${#title}
# Note $ is not needed before numeric variables
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "*"
printf "%${span}s\n" "$title"
printf "%${COLUMNS}s" " " | tr " " "*"
$nocolor

# Get started prompts
$cyan; echo -e -n "\n\nLets setup a hidden service, shall we? [Press Enter to cont]"
$nocolor
read

# Check if Root user
if [ "$USER" != "root" ]; then
	$red; echo -e "\nRTFM asshole. This script must be run as root.\nYou'll need to run \"sudo su\" first, please and thanks."
	$nocolor
	exit 0
fi

# Step 1: Set Directory name and Ports
until [ "$confirmed" = "Confirmed" ]; do

	# Hidden Servide Directory assign
	read -p $'\n\nDesired name for the HiddenService directory\n[example: monero] ' hsdir
	read -p $'Enter the port for the .onion domain\n[example: 18089] ' onionport
	read -p $'Enter the local port which your service will run on\n[example: 18089] ' localport

	# Read Values
	TOR_HS=/var/lib/tor/$hsdir
	torrcwrite="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport 127.0.0.1:$localport\n"		# Variable for sed input
	torrcreplace1="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport 127.0.0.1:$localport\n" 	# Variable for sed replacement if adding second service but first is configured

	# Do we add services to the onion?
	read -p $'\nWould you like to add another service to this Onion? [y/N] ' addservice
	additional=$(
		case $addservice in
			y|Y) echo "add";;
			*) echo "finished";;
		esac)
	if [ "$additional" = "add" ]; then
		read -p $'\nEnter the port for the .onion domain\n[example: 18084] ' onionport2
		read -p $'\nEnter the local port which your service will run on\n[example: 18084] ' localport2
		torrcwrite="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport 127.0.0.1:$localport\nHiddenServicePort $onionport2 127.0.0.1:$localport2\n"		# Variable for sed  input
		torrcreplace2="\nHiddenServiceDir $TOR_HS\nHiddenServicePort $onionport2 127.0.0.1:$localport2\n"		# Variable for sed replacement
	fi

	# Confirm all Details
	$cyan; echo -e "$torrcwrite";	# This is what we will write to torrc
	$nocolor
	read -p $'Does this look good? [Y/n] ' abort
	confirmed=$(
		case $abort in
			n|N) echo "Try Again";;
			*) echo "Confirmed";;
		esac)
	if [ "$confirmed" = "Try Again" ]; then $red; else $green; fi
	echo -e "$confirmed"
	$nocolor
done

# Step 2: Install Tor
torinstall=$(apt-cache policy tor | grep "Installed:" | grep -E -o "[0-9]\w+")
if [  "$torinstall" ]; then
	echo -e "\nTor is already installed"
else
	echo "Installing Tor..."
	sleep 1
	apt update && apt upgrade -y
	apt install tor -y
fi

# Create HiddenService dir within /var/lib/tor and change both permissions and ownership
if ! [ -e "$TOR_HS" ]; then
	echo "Creating $hsdir HiddenService directory and setting permissions"
	mkdir $TOR_HS
	chmod 700 $TOR_HS
	chown -R debian-tor:debian-tor $TOR_HS
fi

# Step 3: Edit torrc file
cp /etc/tor/torrc /etc/tor/torrc.old
# Check if already configured
HSDIR=$(grep -E "$hsdir Hidden" /etc/tor/torrc)	# -E, --extended-regexp : Interpret PATTERNS as extended regular expressions
HSDIR2=$(grep -E $TOR_HS /etc/tor/torrc)
ONIONPORT=$(grep -E $onionport /etc/tor/torrc)
LOCALPORT=$(grep -E $localport /etc/tor/torrc)
if [[ "$onionport2" && "localport2" ]]; then
	ONIONPORT2=$(grep -E $onionport2 /etc/tor/torrc)
	LOCALPORT2=$(grep -E $localport2 /etc/tor/torrc)
	if [[ "$ONIONPORT" && "$LOCALPORT" && "$ONIONPORT2" && "$LOCALPORT2" && "$HSDIR" ]]; then
		$cyan; echo -e "\n$HSDIR2\n$LOCALPORT\n$LOCALPORT2\n\nAbove Hidden Service(s) have existing configurations, so skipping\n"
		$nocolor
		sleep 2
	elif [[ "$ONIONPORT" && "$LOCALPORT" && "$HSDIR" ]]; then
		echo "Partially configured.. fixing"
		sed -i -z s"|$torrcreplace1|$torrcwrite|" /etc/tor/torrc
	elif [[ "$ONIONPORT2" && "$LOCALPORT2" && "$HSDIR" ]]; then
		echo "Partially configured.. fixing"
		sed -i -z s"|$torrcreplace2|$torrcwrite|" /etc/tor/torrc
	else
		echo "Editing torrc file..."
		sed -i -z s"|#HiddenServicePort 22 127.0.0.1:22\n|#HiddenServicePort 22 127.0.0.1:22\n\n# $hsdir Hidden Service$torrcwrite|" /etc/tor/torrc
	fi
else
	if [[ "$ONIONPORT" && "$LOCALPORT" && "$HSDIR" ]]; then
		$cyan; echo -e "\n$HSDIR2\n$LOCALPORT\n\nAbove Hidden Service(s) have existing configurations, so skipping\n"
		$nocolor
		sleep 2
	else
		echo "Editing torrc file..."
		sed -i -z s"|#HiddenServicePort 22 127.0.0.1:22\n|#HiddenServicePort 22 127.0.0.1:22\n\n# $hsdir Hidden Service$torrcwrite|" /etc/tor/torrc
	fi
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
$green; printf "%${span}s\n" "$footer"; $nocolor
printf "%${COLUMNS}s" " " | tr " " "*"
# sed -i s"/\$ONION/$ONION/" .btcpayserver/Main/settings.config
