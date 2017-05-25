#!/bin/bash

function set_airport {

    new_status=$1

    if [ $new_status = "On" ]; then
        /usr/sbin/networksetup -setairportpower $air_name on
        touch /var/tmp/prev_air_on
    else
        /usr/sbin/networksetup -setairportpower $air_name off
        if [ -f "/var/tmp/prev_air_on" ]; then
            rm /var/tmp/prev_air_on
        fi
    fi

}

function notify {
    if [[ -f "/usr/local/bin/terminal-notifier" ]]; then
      /usr/local/bin/terminal-notifier -title "Wifi Toggle" -message \"$1\" -timeout 3 >/dev/null 2>&1 &
    else
      /usr/bin/osascript -e "display notification \"$1\" with title \"Wifi Toggle\" sound name \"Hero\""
    fi
}

# Set default values
prev_eth_status="Off"
prev_air_status="Off"
eth_status="Off"

# Grab the names of the adapters. We assume here that any ethernet connection name ends in "Ethernet"
eth_names=`networksetup -listnetworkserviceorder | sed -En 's|^\(Hardware Port: .*Ethernet, Device: (en.)\)$|\1|p'`
air_name=`networksetup -listnetworkserviceorder | sed -En 's/^\(Hardware Port: (Wi-Fi|AirPort), Device: (en.)\)$/\2/p'`

# Determine previous ethernet status
# If file prev_eth_on exists, ethernet was active last time we checked
if [ -f "/var/tmp/prev_eth_on" ]; then
    prev_eth_status="On"
fi

# Determine same for AirPort status
# File is prev_air_on
if [ -f "/var/tmp/prev_air_on" ]; then
    prev_air_status="On"
fi

# Check actual current ethernet status
for eth_name in ${eth_names}; do
    if ([ "$eth_name" != "" ] && [ "`ifconfig $eth_name | grep "status: active"`" != "" ]); then
        eth_status="On"
    fi
done

# And actual current AirPort status
air_status=`/usr/sbin/networksetup -getairportpower $air_name | awk '{ print $4 }'`

pushd ./ >/dev/null
SCRIPTPATH=$(cd $(dirname $0);pwd)
popd >/dev/null

# If any change has occured. Run external script (if it exists)
if [ -f "${SCRIPTPATH}/statusChanged.sh" ]; then
  if [ "$prev_air_status" != "$air_status" ] || [ "$prev_eth_status" != "$eth_status" ]; then
     "${SCRIPTPATH}/statusChanged.sh" "$eth_names:$prev_eth_status->$eth_status" "$air_name:$prev_air_status->$air_status"
 fi
fi

# Determine whether ethernet status changed
if [ "$prev_eth_status" != "$eth_status" ]; then

    if [ "$eth_status" = "On" ]; then
        if [ "$prev_air_status" != "Off" ]; then
          set_airport "Off"
          notify "Wired network detected. Turning AirPort off."
        fi
    else
        if [ "$prev_air_status" = "Off" ]; then
          set_airport "On"
          notify "No wired network detected. Turning AirPort on."
        fi
    fi

# If ethernet did not change
else

    # Check whether AirPort status changed
    # If so it was done manually by user
    if [ "$prev_air_status" != "$air_status" ]; then
    set_airport $air_status

    if [ "$air_status" = "On" ]; then
        notify "AirPort manually turned on."
    else
        notify "AirPort manually turned off."
    fi

    fi

fi

# Update ethernet status
if [ "$eth_status" == "On" ]; then
    touch /var/tmp/prev_eth_on
else
    if [ -f "/var/tmp/prev_eth_on" ]; then
        rm /var/tmp/prev_eth_on
    fi
fi

exit 0
