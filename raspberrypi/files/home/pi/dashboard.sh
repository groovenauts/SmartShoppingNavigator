#!/bin/bash

xset -dpms
xset s off

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/pi/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/pi/.config/chromium/Default/Preferences

chromium-browser --noerrdialogs --window-position=0,0 --window-size=800,480 --kiosk https://www.google.com/
