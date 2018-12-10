#!/bin/ash

echo "[btn_link,pressed]" > /var/hue-ipbridge/button_in
sleep 1
echo "[btn_link,released]" > /var/hue-ipbridge/button_in

