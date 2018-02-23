Pushing Hue
===========

Making the Hue hub push status updates to home assistant.
Because polling is just not good enough.


## Root

- got new 2.1 hub
  - hardware revision
  - known hw attack impossible
  - used as temp replacement
- going back to 2.0
  - got root via known hack
  - [insert links here]

## Exploring and dumping the system

- netcat is available!
  - dumping fs through tar and nc
- inspecting running processes and- init scripts
  - hueipbridge - main hue binary
  - swupdate - shell script 'daemon'
- readlogs
  - seems interesting but complicated
- opkg is gone in latest firmware
  - noooooo
  - can it somehow ne brought back?
    - I almost always failed in cross compiling
    - maybe extract it from an older fw

## Extracting firmware images

- downloaded url are known 
  - or can be guessed
- some infos were available
  - rsa key at the end
- hex viewer
  - found version number between the
    big blob and thr rsa key
  - the lenght of the key is some bytes before that 
  - guess what: its the same before the block

### patching and exploiting swupdate
- should run within dumped fs structure
- override/fske some functions
- prefix all paths to use the dump folder
- exit between extracting and writing to mtds

- run it with
  - fw image and
  - values learned from hexdump as attributes
- boom! the image is decrypted an split
- kernel image
  - not of interest for now
- ubi image
  - never heard of...
  - but there are tools on github
    - [link missing]
- extracted fs! hell yeah :-)

- tried using opkg from old image
  - copied some missing lib - forgot which :doh:
  - Segmentation fault - double-:doh:
  - maybe try extracting a newer fw?
- well, we'll have to live with what we got for now
  - luckily ash, grep, sed, wget, netcat and more are available


So far, so good. Now lets look at the actual hue stuff besides the os.

## looking for triggers

- readlogs it is

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

to be continued...
