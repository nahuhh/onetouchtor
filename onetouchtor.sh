#!/bin/bash
#Purpose: Automate XMR Tor Hidden Service
# START #
# Title Bar
title="Installing BTCpayserver's Tor Hidden Service"
COLUMNS=$(tput cols)
title_size=${#title}
# Note $ is not needed before numeric variables
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "*"
printf "%${span}s\n" "$title"
printf "%${COLUMNS}s" " " | tr " " "*"

TOR_HS=/var/lib/tor/xmrbtc
read -p "Lets setup a hidden service, shall we? [Press Enter]"
# Step 1: Install Tor
echo "Installing Tor..."
apt install tor -y 
# Step 2: Edit torrc file
echo "Editing torrc file..."
cp /etc/tor/torrc .
# -E, --extended-regexp : Interpret PATTERNS as extended regular expressions
HS=$(grep -E [0123]{5}$ /etc/tor/torrc)
if [ -n "$HS" ]
then
printf "$HS \n Above Hidden Service files already exist, so skipping\n"
else
printf "Adding Tor HS for BTCpayserver"
sed -i -z \
s"|#HiddenServicePort 22 127.0.0.1:22\
\n|#HiddenServicePort 22 127.0.0.1:22\n\
\n# BTCpayserver Hidden Service\
\nHiddenServiceDir /var/lib/tor/xmrbtcpay\
\nHiddenServicePort 23001 127.0.0.1:23001|" /etc/tor/torrc
fi
sleep 1

# Step 3: Determine which approach to logging you will use
echo "Setting log levels within torrc..."
sleep 2

NOT=$(grep "#Log notice file" /etc/tor/torrc)
DEB=$(grep "#Log debug file" /etc/tor/torrc)
STDR=$(grep "#Log debug stderr" /etc/tor/torrc)
SYS=$(grep "#Log notice syslog" /etc/tor/torrc)

if [[ "$NOT" && "$DEB" && "$STDR" && "$SYS" ]]; then
        echo "
        1. Send notice-level or higher messages to /var/log/tor/notices.log
        2. Send all level messages to /var/log/tor/debug.log
        3. Send all level messages to stderr
        4. Use the system log instead of Tor logfiles"
until [[ "$l" =~ ^[1234]$ ]]
do
read -r -p "Please choose a logging method (notice-level logging is recommended): " l
    case $l in
        1)
        echo "You chose to send notice-level or higher messages to /var/log/tor/notices.log"
        sed -i -z s"|#Log notice file /var/log/tor/notices.log|Log notice file /var/log/tor/notices.log|" /etc/tor/torrc
        ;;
        2)
        echo "You chose to send all level messages to /var/log/tor/debug.log"
        sed -i -z s"|#Log debug file /var/log/tor/debug.log|Log debug file /var/log/tor/debug.log|" /etc/tor/torrc
        ;;
        3)
        echo "You chose to send all level messages to stderr"
        sed -i -z s"|#Log debug stderr|Log debug stderr|" /etc/tor/torrc
        ;;
        4)
        echo "You chose to use the system log instead of Tor logfiles"
        sed -i -z s"|#Log notice syslog|Log notice syslog|" /etc/tor/torrc
        ;;
        *)
        echo "Invalid Option $l: Select 1-4 above"
        ;;
     esac
done
else
        echo "Logging already configured. Skipping";
fi
sleep 5
# Step 4: Create xmrbtcpay dir within /var/lib/tor and change both permissions and ownership"]
if [ -d $TOR_HS ]; then
        printf "xmrbtcpay HiddenService is already configured.\nCopy it here: $(cat $TOR_HS/hostname)"
else
        echo "Creating /var/lib/tor/xmrbtcpay HiddenService directory..."
        mkdir $TOR_HS
        chmod 700 $TOR_HS
        chown -R debian-tor:debian-tor $TOR_HS
fi

#Step 5: Start Tor to generate hostname (onion address) in /var/lib/tor/xmrbtcpay
# and copying hostname
if [ -e /var/lib/tor/xmrbtcpay/hostname ]; then
        ONION=`cat /var/lib/tor/xmrbtcpay/hostname`
        echo "Your Onion address is $ONION"
else
        echo "Please wait while Tor restarts to generate your HiddenService"
        systemctl restart tor
        sleep 7
        echo "Copying hostname..."
        sleep 2
        ONION=`cat /var/lib/tor/xmrbtcpay/hostname`
        echo "Your Onion address is $ONION"
fi
