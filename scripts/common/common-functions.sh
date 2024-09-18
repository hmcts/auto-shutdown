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

function read_date() {
    IFS='-' read -r day month year <<< "$1"
    local valid_date="$year-$month-$day"
    local timestamp=$($date_command -d "$valid_date" +%Y-%m-%d)
    echo "$timestamp"
}



function is_late_night_run() {
  local current_hour=$(get_current_hour)

  # Remove leading zeros to play nice with jq
  current_hour=$(echo $current_hour | sed 's/^0*//')

  log "current hour result: $(get_current_hour)"
  if [[ $current_hour -gt 20 ]]; then
    log "is_late_night_run: set to 'true'"
    echo "true"
  else
    echo "false"
    log "is_late_night_run: set to 'false'"
  fi
}

# Function to check if a date is a weekend
function is_weekend_day() {
    if [ -z "$1" ]; then
      local current_date=$(get_current_date)
      log "current_date defaulted to: $current_date"
    else
      local current_date=$1
      log "current_date set to: $current_date"
    fi

    local day_of_week=$($date_command -d "$current_date" +"%u")
    log "day_of_week var set to $day_of_week"

    if [[ $day_of_week -ge 5 ]]; then
        log "weekend day found"
        echo "true"  # Weekend
    else
        log "weekend day not found"
        echo "false" # Weekday
    fi
}

# Function to iterate through the date range and check for weekends
function is_weekend_in_range() {
    local start_date=$(read_date $1)
    log "start_date set to '$start_date'"
    local end_date=$(read_date $2)
    log "end_date set to '$end_date'"
    local current_date=$start_date
    local weekend_in_range="false"

    while [[ "$current_date" < "$end_date" || "$current_date" == "$end_date" ]]; do
        if [[ $(is_weekend_day "$current_date") == "true" ]]; then
            weekend_in_range="true"
        fi
        current_date=$($date_command -I -d "$current_date +1 day")
    done

    if [[ $weekend_in_range == "true" ]]; then
        log "Provided dates include a weekend within scope"
        echo "true"
    else
        log "Provided dates do not include a weekend within scope"
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
  log "Checking function input vars"
  log "env set to $env"
  log "business_area set to $business_area"
  log "mode set to $mode"
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

    # determine if we should continue checking the resource for an exclusion
    if [[ ($request_type == "stop" && $mode == "deallocate") || $request_type == $mode ]]; then
      check_resource="true"
    else
      check_resource="false"
    fi

    if [[ $check_resource == "false" ]]; then
      continue
    fi
    
    if [[ ($mode == "stop" || $mode == "deallocate") && $env_entry =~ $env && $business_area == $business_area_entry && $(is_in_date_range $start_date $end_date) == "true" ]]; then
    log "Exclusion FOUND"
      if [[ $(is_late_night_run) == "false" ]]; then
        log "== 20:00 run =="
        log "skip set to 'true as an exclusion request was found for this resource at the 20:00 run'"
        echo "true"
      elif [[ $(is_late_night_run) == "true" && $stay_on_late == "Yes" ]]; then
        log "== 23:00 run =="
        log "skip set to 'true' as an exclusion request was found at 23:00 with 'stay_on_late' var set to $stay_on_late "
        echo "true"
      elif [[ $(is_late_night_run) == "true" && $stay_on_late == "No" && $(is_weekend_in_range $start_date $end_date) == "true" && $(is_weekend_day) == "true" ]]; then
        log "== 23:00 run =="
        log "skip set to 'true' as an exclusion request was found at 23:00 with 'stay_on_late' var set to $stay_on_late, however shutdown will still be skipped as this is running at the weekend and the environment is required over the weekend."
        echo "true"
      else
        log "defaulting skip var to false"
        echo "false"
      fi
      return
    log "No exclusion request found"
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