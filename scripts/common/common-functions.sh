#!/bin/bash
# Check platform
platform=$(uname)

# Check and install missing packages
if [[ $platform == "Darwin" ]]; then
    date_command=$(which gdate)
elif [[ $platform == "Linux" ]]; then
    date_command=$(which date)
fi

function ts_echo() {
    date +"%H:%M:%S $(printf "%s "  "$@")"
}

function notification() {
    local channel="$1"
    local message="$2"
    curl -X POST --data-urlencode "payload={\"channel\": \"$channel\", \"username\": \"AKS Auto-Start\", \"text\": \"$message\", \"icon_emoji\": \":tim-webster:\"}" \
        ${registrySlackWebhook}
}

function get_current_date_seconds() {
  local current_date_formatting
  current_date_formatting=$($date_command +'%Y-%m-%d')
  $date_command -d "$current_date_formatting 00:00:00" +%s
}

function convert_date_to_timestamp() {
    IFS='-' read -r day month year <<< "$1"
    local valid_date="$year-$month-$day"
    local timestamp=$($date_command -d "$valid_date" +%s)
    echo "$timestamp"
}

function is_in_date_range() {
  local start_date_seconds end_date_seconds current_date_seconds
  start_date_seconds=$(convert_date_to_timestamp "$1")
  end_date_seconds=$(convert_date_to_timestamp "$2")
  current_date_seconds=$(get_current_date_seconds)

  if [[ $current_date_seconds -ge $start_date_seconds && $current_date_seconds -le $end_date_seconds ]]; then
    echo "true"
  else
    echo "false"
  fi
}

get_request_type() {
  local issue=${1}
  request_type=$(jq -r '."requesttype"' <<< $issue | tr '[:upper:]' '[:lower:]')
  if [[ $request_type == *"start"* ]]; then
    request_type="start"
  else
    request_type="stop"
  fi
}