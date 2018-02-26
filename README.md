Pushing Hue
===========

Making the Hue hub push status updates to home assistant.  
Because polling is just not good enough.

# Features
- listen to state changes directly on the hue hub
- push states to home assistant
- supported devices
  - bulbs including brightness (not triggering for brightness changes)
  - motion sensors
  - temperature sensor (included in motion sensor)
  - dimmer switches

# Caveat
You need a serial-to-usb adapter and unscrew your hub, probably voiding your warranty.
I'll take no responsibility whatsoever to what you do to your devices.

# How I did it
Short version:
- get shell access to the hub
- use (b)ash script to
  - listen to log messages
  - call the home assistant api

The rest of this document are just some notes for now, but maybe I'll clean this up someday.

## Root

- got new 2.1 hub
  - hardware revision
  - known hw attack impossible
  - used as a temp replacement while hacking the other one - the lights need to work while experimenting
- going back to 2.0
  - got root via known hack
  - mixed and matched information from the following resources - Thanks for sharing!
	(in no particular order and maybe incomplete!)
	- https://github.com/Tristan79/HUEHack
	- http://colinoflynn.com/2016/07/getting-root-on-philips-hue-bridge-2-0/ 
	- https://medium.com/@rxseger/enabling-the-hidden-wi-fi-radio-on-the-philips-hue-bridge-2-0-42949f0154e1

## Exploring and dumping the system

- netcat is available!
  - dumping fs through tar and nc
- inspecting running processes and init scripts
  - /usr/sbin/ipbridge - main hue binary
  - /usr/sbin/swupdate - shell script 'daemon'
- logread
  - seems interesting but complicated
- opkg is gone in latest firmware
  - noooooo
  - can it somehow be brought back?
    - I almost always failed in cross compiling
    - maybe extract it from an older fw

## Extracting firmware images

This part is not necessary for what I came up in the end, but my first plan was different.
Nevertheless extracting and analyzing firmware updates before applying them, could come
in handy in the future.

- download urls are known 
  - or can be guessed
- some info was available
  - rsa key at the end
- hex viewer
  - found version number between the
    big blob and the rsa key
  - the length of the key is some bytes before that
  - guess what: its the same before the blob

### patching and exploiting swupdate

I used the firmware updating script of the hub to extract the images.
For that I modified it to run inside a dump of the fs.
I decided not to publish any patches that could potentialy include
copyrighted code, but I will briefly describe what changes I made. So once
you gained access to the hub yourself, you may recreate my steps.

- prefix all paths to use the dump folder
- override/fake uboot env
  - define fw_printenv and fw_setenv as shell functions
  - dump uboot env to file or analyze used values
- exit between extracting and writing to mtds
  - leaving the extracted files in the dumps temp dir

- run it with
  - the fw image and
  - the values learned from the hexdump as attributes
- boom! the image is decrypted and split
- kernel image
  - not of interest for now
- ubi image
  - never heard of, but there are tools on github
  - this one worked for me, installed via pip: https://github.com/jrspruitt/ubi_reader
- extracted fs from root.bin! hell yeah :-)

### well...
- tried using opkg from old image
  - copied some missing lib - forgot which :doh:
  - Segmentation fault - double-:doh:
  - maybe try extracting from a newer fw?
- well, we'll have to live with what we got for now
  - luckily ash, grep, sed, wget, netcat and more are available


So far, so good. Now lets look at the actual hue stuff besides the os.

## looking for triggers

- looking for some events I could listen to
  - I don't want (and can't) disassemble the ipbridge binary
  - needed tools to MitM the zigbee-device not available
    - /dev/Zigbee is a symlink to /dev/ttyUSB0
    - remove link, read from ttyUSB0, push data to simulate /dev/Zigbee
    - simulating ttys isn't possible (or is it?) with available tools

### logread it is

- spits out a buttload of messages
- some say sth about "statelog" followed by some cyptic values
- format like 'T:[CLIP|RULES|ZIGBEE|...], M:[int], R:[int], ID:[int], A:[16 bytes hex]'
- ID is the index of the hue device (bulb or sensor)
- (seems like) there is no information about the actual state,
  but at least we see which device changed
- after some analysis and fiddling, listening to messages containing
  - `T:CLIP.*R:0\|T:RULES.*R:2` for lights
  - `T:ZIGBEE.*R:6` for sensors

## hass api

- mostly straight forward using the docs
- except: you can't push single attributes of a state
  - you have push the full state json
- simple solution: get json, replace attributes, push back

## putting it all together

- (b)ash script
  - readlogs piped into a loop
    - builtin filter parameter
  - wget to pull/push to hass
  - in between some sed, grep...

# Todo

- clean up...
- inspect swupdate
	- ideally there's a way for the mods to survive an upgrade
	- if not, maybe there's a way to manually upgrade (parts of) the fw
- retry bringing back opkg
  - being able to install some tools would be really helpful

