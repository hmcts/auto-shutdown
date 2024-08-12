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
  printf "%s $(printf "%s "  "$@")\n" "$(get_current_time)"
}

function ts_echo_color() {
    color=$1
    shift
    case $color in
        RED)
            color_code="\033[0;31m"
            ;;
        GREEN)
            color_code="\033[0;32m"
            ;;
        BLUE)
            color_code="\033[0;34m"
            ;;
        AMBER)
            color_code="\033[0;33m"
            ;;
        *)
            color_code=""
            ;;
    esac
    printf "%s $(printf "${color_code}%s\033[0m"  "$@")\n" "$(get_current_time)"
}

#Outputs text to scripts/common/log.txt
#log contents output to pipeline via ./scripts/common/log-output.sh
#Usage: log "message to log, including $vars"
function log() {
  ts_echo "$1" >> scripts/common/log.txt
}

function notification() {
    local channel="$1"
    local message="$2"
    curl -X POST --data-urlencode "payload={\"channel\": \"$channel\", \"username\": \"AKS Auto-Start\", \"text\": \"$message\", \"icon_emoji\": \":tim-webster:\"}" \
        ${registrySlackWebhook}
}

function auto_shutdown_notification() {
    local message="$1"

    # This silences the slack response message in logs.
    # Comment this line out if you are having issues with slack delivery and want to see responses in your terminal
    local silentResponse="-s -o /dev/null"

    curl $silentResponse -X POST --data-urlencode "payload={\"username\": \"Auto Shutdown Notifications\", \"text\": \"$message\", \"icon_emoji\": \":tim-webster:\"}" \
      ${notificationSlackWebhook}
}

function get_current_date() {
  $date_command +'%d-%m-%Y %H:%M'
}

function get_current_hour() {
  $date_command +'%H'
}

function get_current_time() {
  $date_command +'%H:%M:%S'
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

function is_late_night_run() {
  if [[ $(get_current_hour) -gt 20 ]]; then
    echo "true"
  else
    echo "false"
  fi
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
  # If its not onDemand we don't need to check the file issues_list.json for startup
  if [[ $STARTUP_MODE != "onDemand" && $mode == "start" ]]; then
    echo "false"
    return
  fi
  while read issue; do
    local env_entry business_area_entry start_date end_date stay_on_late
    env_entry=$(jq -r '."environment"' <<< $issue)
    business_area_entry=$(jq -r '."business_area"' <<< $issue)
    start_date=$(jq -r '."start_date"' <<< $issue)
    end_date=$(jq -r '."end_date"' <<< $issue)
    stay_on_late=$(jq -r '."stay_on_late"' <<< $issue)
    get_request_type "$issue"

    if [[ $request_type != $mode ]]; then
      continue
    fi
    if [[ ($mode == "stop" || $mode == "deallocate") && $env_entry =~ $env && $business_area == $business_area_entry && $(is_in_date_range $start_date $end_date) == "true" ]]; then
      if [[ $(is_late_night_run) == "false" ]]; then
        echo "true"
      elif [[ $(is_late_night_run) == "true" && $stay_on_late == "Yes" ]]; then
        echo "true"
      else
        echo "false"
      fi
      return
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

get_slack_displayname_from_github_username() {
    local github_username="$1"

    # Using curl to fetch content from github-slack-user-mappings repo
    local user_mappings=$(curl -sS "https://raw.githubusercontent.com/hmcts/github-slack-user-mappings/master/slack.json")

    # Filtering JSON data based on GitHub field using jq
    local slack_id=$(echo "$user_mappings" | jq -r ".users[] | select(.github == \"$github_username\") | .slack")

    if [[ -z $slack_id ]]; then
        #setting output to input GitHub username as slack mapping doesn't exist.
        echo $github_username
    else
        # Slack API request to get user information based on ID.
        local url="https://slack.com/api/users.profile.get?include_labels=real_name&user=$slack_id&pretty=1"
        local data='{"user": "'"$slack_id"'"}'
        local response=$(curl -s -X POST \
            -H "Authorization: Bearer $SLACK_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" "$url")

        local slack_real_name=$(echo "$response" | jq -r '.profile.real_name')
        echo $slack_real_name
    fi
}