#!/bin/ash

# hue2hass - push hue events to hass

## Preparation
# - place this script on the hue hub
# - create .hue2hass.secrets in the same folder
# - define the following four variables in that file
# - altetnative: set these vars right here, but don't publish them ;-)

hue_user=""
hue_url="http://127.0.0.1/api/"

hass_pw=""
hass_url=""

## Usage
# ash /path/to/hue2hasd.sh [-v] [-q]
# parameters
#  -v  verbose logging
#  -q  no logging at all
#
# example (run in background):
#  ash /path/to/hue2hasd.sh > /dev/null &

## Logs
# By default logs are wtitten to stdout and the file 'hass.log'
# in the same folder as the script
# The file is truncated to 100 entries when reaching 200 entries.

[ -f "$(dirname "$0")/.hue2hass.secrets" ] && . "$(dirname "$0")/.hue2hass.secrets"

hue_url="${hue_url}${hue_user}"

[ "$1" == "-v" ] && verbose="1"
[ "$1" == "-q" ] && quiet="1"

log_file="$(dirname "$0")/hass.log"
logs=0

logdate() {
  date "+%Y-%m-%d %H:%M:%S"
}

log() {
  [ -n "$quiet" ] && return
  echo "$(logdate) " "$@" | tee -a $log_file
  logs=$(( logs + 1))
  if [ $logs -gt 200 ]; then
  	cp "$log_file" "$log_file".old
  	tail -99 "$log_file" > "$log_file".old 
  	mv "$log_file".old "$log_file"
  	logs=99
  	log "logs truncated"
  fi
}

info() {
  [ -n "$verbose" ] && log "$@"
}

queryHueLight() {
    info "queryHueLight light_index=$1"
    hue_status="$(wget -q -O - "$hue_url/lights/$1" | sed 's/{/{\n/g;s/}/\n}\n/g;s/,/,\n/g')"
}

queryHueSensor() {
    info "queryHueSensor index=$1"
    hue_status="$(wget -q -O - "$hue_url/sensors/$1" | sed 's/{/{\n/g;s/}/\n}\n/g;s/,/,\n/g')"
}

getProp() {
	echo "$hue_status" | sed '/^"'"$1"'":/!d;s/^"'"$1"'":"\?//;s/"\?,$//'
}

hueLightToHass() {
	queryHueLight "$1"

	id="$(getProp uniqueid)"
	name="$(getProp name)"
	bri="$(getProp bri)"
	on="$(getProp on)"

	# [ "$bri" == "1" ] && return

	[ "$on" == "true" ] && on="on" || on="off"
	entity_id="light.$(getEntityId "$name")"
	state="$(prepareLightState "$entity_id" "$on" "$bri")"

	pushToHass "$entity_id" "$state"
}

## todo: get rid of hard coding :-|
hueSensorToHass() {
	case "$1" in
	  2) entity_id="sensor.flur_dimmer"
	  	 attribute="buttonevent";;
	  9) entity_id="sensor.flur_motion_sensor"
	  	 attribute="presence";;
	esac
	
	[ -z "$attribute" ] && return

	queryHueSensor "$1"
	state="$(getProp "$attribute")"
	id="$(getProp uniqueid)"
	name="$(getProp name)"

	[ -z "$state" ] && return
	[ "$state" == "true" ] && state="on"
	[ "$state" == "false" ] && state="off"
	state="$(prepareState "$entity_id" "$state")"

	pushToHass "$entity_id" "$state"
}

getEntityId() {
   echo "$1"| sed 's/ä/a/g;s/ö/o/g;s/ü/u/g;s/ /_/g' | tr A-Z a-z
}

pushToHass() {
    log "pushToHass entity_id=$1"
    info "state=$2"
    # echo wget -q -O - --header="x-ha-access: $hass_pw" --post-data "$2" "$hass_url/api/states/$1"
    wget -q -O - --header="x-ha-access: $hass_pw" --post-data "$2" "$hass_url/api/states/$1" >/dev/null
}

prepareLightState() {
    prepareState "$1" "$2" \
      | sed 's/"brightness":[^,]*,/"brightness":'$3',/'
}

prepareState() {
	# info prepareLightState
	update="$(date -u +"%Y-%m-%dT%H:%M:%S.000000+00:00")"
    getHassState "$1" \
      | sed 's/"state": *"[^"]*"/"state":"'$2'"/' \
	  | sed 's/"last_\(changed\|updated\)":[^,]*,/"last_\1":"'"$update"'",/g'
}

getHassState() {
    wget -q -O - --header="x-ha-access: $hass_pw" "$hass_url/api/states/$1" \
      || echo '{ "state": "", "last_update": 0, "last_change": 0}'
}

parseLogEntry() {
	index="$(echo "$1"| sed 's/^.*, ID:\([^,]*\),.*$/\1/')"
	if echo "$1" | grep -q 'T:CLIP.*R:0\|T:RULES.*R:2'; then
	  info "Light $index changed!"
	  hueLightToHass "$index"
	elif echo "$1" | grep -q 'T:ZIGBEE.*R:6'; then
	  info "Sensor $index changed!"
	  hueSensorToHass "$index"
	fi
}

info "verbose logging enabled"
log "reading hue logs"

logread -e 'T:CLIP.*R:0\|T:RULES.*R:2\|T:ZIGBEE.*R:6' -f \
  | while read log_entry; do
	parseLogEntry "$log_entry"
done

