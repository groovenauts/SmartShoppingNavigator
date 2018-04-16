#!/bin/sh

xset -dpms
xset s off
#chromium-browser --app https://www.magellanic-clouds.com/
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/pi/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/pi/.config/chromium/Default/Preferences

chromium-browser --noerrdialogs --kiosk https://www.magellanic-clouds.com/