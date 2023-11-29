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

function should_skip_start_stop () {
  local env business_area issue
  env=$1
  business_area=$2
  mode=$3
  # If the vm is not onDemand we don't need to check the file issues_list.json for startup
  if [[ $STARTUP_MODE != "onDemand" && $mode == "start" ]]; then
    echo "false"
    return
  fi
  while read issue; do
    local env_entry business_area_entry start_date end_date
    env_entry=$(jq -r '."environment"' <<< $issue)
    business_area_entry=$(jq -r '."business_area"' <<< $issue)
    start_date=$(jq -r '."start_date"' <<< $issue)
    end_date=$(jq -r '."end_date"' <<< $issue)
    get_request_type "$issue"

    if [[ $request_type != $mode ]]; then
      continue
    fi
    if [[ $env_entry =~ $env && $business_area == $business_area_entry ]]; then 
      if [[ $(is_in_date_range $start_date $end_date) == "true" ]]; then
        if [[ $mode == "stop" ]]; then
          echo "true"
        else
          echo "false"
        fi
        return
      fi
    fi
  done < <(jq -c '.[]' issues_list.json)
# If its onDemand and there are no issues matching above we should skip startup
  if [[ $STARTUP_MODE == "onDemand" && $mode == "start" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

get_request_type() {
  local issue=${1}
  request_type=$(jq -r '."request_type"' <<< $issue | tr '[:upper:]' '[:lower:]')
  # default to stop if not defined
  if [[ -z $request_type || $request_type == "null" ]]; then
    request_type="stop"
  fi
}