#!/bin/bash
# Check platform
platform=$(uname)

AUTO_SHUTDOWN_STATUS_CHANNEL_NAME="#auto-shutdown-status"

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

# Function to convert a string to lowercase
to_lowercase() {
    local input="$1"
    local lowercase="${input,,}"  # Convert to lowercase using parameter expansion
    echo "$lowercase"
}

#Outputs text to scripts/common/log.txt
#log contents output to pipeline via ./scripts/common/log-output.sh
#Usage: log "message to log, including $vars"
function log() {
  ts_echo "$1" >> scripts/common/log.txt
}

function post_entire_autoshutdown_thread() {
  local header_message="$1"
  local messages="$2"
  if [[ -n "$messages" ]]; then
    local thread_ts=$(post_autoshutdown_status_header "$header_message")
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      post_autoshutdown_status_to_thread "$line" "$thread_ts"
    done < <(echo "$messages" | tr '|' '\n')
  fi
}


function post_autoshutdown_status_header() {
  local channel_name="$AUTO_SHUTDOWN_STATUS_CHANNEL_NAME"
  local message="$1"
  thread_ts=$(post_header_message "${channel_name}" "${message}")
  echo "$thread_ts"
}

function post_autoshutdown_status_to_thread() {
  local channel_name="$AUTO_SHUTDOWN_STATUS_CHANNEL_NAME"
  local header_message="$1"
  local thread_ts="$2"
  
  post_thread_message "${channel_name}" "${header_message}" "${thread_ts}"
}

function post_header_message() {
  local channel_name="$1"
  local header_message="$2"
  local payload=$(jq -n \
      --arg channel "${channel_name}" \
      --arg header_message "${header_message}" \
      '{channel: $channel, blocks: [{type: "header", text: {type: "plain_text", text: $header_message, emoji: true}}, {type: "divider"}], unfurl_links: false}')

  local response=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_TOKEN" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data "${payload}" "https://slack.com/api/chat.postMessage")

  local thread_ts=$(echo $response | jq -r '.ts')
  echo "$thread_ts"
}

function post_thread_message() {
  local channel_name="$1"
  local thread_message="$2"
  local thread_ts="$3"
  local payload=$(jq -n \
      --arg channel_name "${channel_name}" \
      --arg thread_ts "${thread_ts}" \
      --arg thread_message "${thread_message}" \
      '{channel: $channel_name, thread_ts: $thread_ts, text: $thread_message, unfurl_links: false}')
    
  local response=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_TOKEN" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data "${payload}" "https://slack.com/api/chat.postMessage")
}

function notification() {
  local channel="$1"
  local message="$2"
  curl -X POST \
    -H "Content-Type: application/json" \
    -d "{\"channel\": \"$channel\", \"text\": \"$message\"}" \
    "${registrySlackWebhook}"
}

# Saves to JSON file in this repo which is to be used by another repo for daily-monitoring
function add_to_json() {
  local id="$1"
  local resource="$2"
  local statusMessage="$3"
  local resourceType="$4"
  local mode="$5"
  # Send to json file dependent on resource type
  local pathToJson="status/${resourceType}_status_updates_${mode}.json"

  # Create dir if not exists
  mkdir -p status

  # Create JSON file if it does not exist or is empty
  if [[ ! -f "$pathToJson" || ! -s "$pathToJson" ]]; then
    echo "[]" > "$pathToJson"
  fi

  # Update the existing object if the ID is found, else add a new object
  # Saves us duplicates if there is another individual pipeline run during the day, whilst still allowing for potential status updates
  jq --arg id "$id" --arg resource "$resource" --arg statusMessage "$statusMessage" --arg resourceType "$resourceType" \
   'map(if .id == $id then
          .resource = $resource |
          .statusMessage = $statusMessage |
          .resourceType = $resourceType
        else
          .
        end)
    + (if any(.id == $id) then [] else
        [{
          "id": $id,
          "resource": $resource,
          "statusMessage": $statusMessage,
          "resourceType": $resourceType
        }]
      end)' "$pathToJson" \
   > "json_file.tmp" && mv "json_file.tmp" "$pathToJson"
  echo "JSON file updated successfully."
}

function get_current_date_time() {
  $date_command +'%d-%m-%Y %H:%M'
}

function get_current_date() {
  $date_command +'%Y-%m-%d'
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
  if [[ $current_hour -gt 20 || $current_hour -lt 05 ]]; then
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
    else
      local current_date=$1
    fi

    local day_of_week=$($date_command -d "$current_date" +"%u")

    if [[ $day_of_week -ge 5 ]]; then
        echo "true"  # Weekend (Fri - Sunday)
    else
        echo "false" # Weekday
    fi
}

# Function to iterate through the date range and check for weekends
function is_weekend_in_range() {
  local start_date=$(read_date $1)
  local end_date=$(read_date $2)

  local current_date=$start_date
  local weekend_in_range="false"

  while [[ "$current_date" < "$end_date" || "$current_date" == "$end_date" ]]; do
    if [[ $(is_weekend_day "$current_date") == "true" ]]; then
      weekend_in_range="true"
      break  # Add break statement to exit the loop
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

function compare_json_lists() {
  # Lists in the format ["item1", "item2", "item3"]
  local json_list1="$1"
  local json_list2="$2"

  # remove whitespace in list entries and make lower case
  local normalized_list1=$(jq -c 'map(gsub("^\\s+|\\s+$"; "") | ascii_downcase)' <<< "$json_list1")
  local normalized_list2=$(jq -c 'map(gsub("^\\s+|\\s+$"; "") | ascii_downcase)' <<< "$json_list2")

  # Compare lists and store matching values in result as JSON list " [] "
  local result=$(jq --argjson list1 "$normalized_list1" --argjson list2 "$normalized_list2" '
    [$list1[], $list2[]] | group_by(.) | map(select(length == 2)) | flatten | unique
  ' <<< '{}')
  # Return result to caller
  echo $result
}

function should_skip_start_stop () {
  local script_env business_area issue
  business_area=$2
  mode=$3
  serviceType=$4
  
  # Check if business shutdown mode is enabled and we're in auto-start mode
  # Business shutdown mode is determined by business_shutdown_config.json file
  # Manual workflows are never affected by business shutdown mode
  if [[ $mode == "start" && -f "business_shutdown_config.json" ]]; then
    local shutdown_mode_enabled=$(jq -r '.enabled // false' business_shutdown_config.json)
    if [[ "$shutdown_mode_enabled" == "true" ]]; then
      # For business shutdown, check if resource is in the allowlist
      local resource_name="${5:-unknown}"
      if ! is_in_business_shutdown_allowlist "$resource_name" "$serviceType"; then
        log "Business shutdown mode ACTIVE: Resource $resource_name not in allowlist - skipping start"
        echo "true"
        return
      fi
      log "Business shutdown mode ACTIVE: Resource $resource_name is in allowlist - proceeding with start"
    fi
  fi
  
  # If its not onDemand we don't need to check the file issues_list.json for startup
  if [[ $STARTUP_MODE != "onDemand" && $mode == "start" ]]; then
    echo "false"
    return
  fi

  late_night_run=$(is_late_night_run)
  log "late_night_run var set to: $late_night_run"
  weekend_day=$(is_weekend_day)
  log "Runtime day is a weekend day (includes Friday): $weekend_day"

  while read issue; do
    local issue_env business_area_entry start_date end_date stay_on_late bastion_required issue_number
    script_env=$1
    issue_env=$(jq -r '."environment"' <<< $issue)
    business_area_entry=$(jq -r '."business_area"' <<< $issue)
    start_date=$(jq -r '."start_date"' <<< $issue)
    end_date=$(jq -r '."end_date"' <<< $issue)
    stay_on_late=$(jq -r '."stay_on_late"' <<< $issue)
    bastion_required=$(jq -r '."bastion_required"' <<< $issue)
    issue_number=$(jq -r '."issue_link"' <<< $issue | cut -d'/' -f7)
    get_request_type "$issue"

    # determine if we should continue checking the resource for an exclusion
    if [[ ($request_type == "stop" && $mode == "deallocate") || $request_type == $mode ]]; then
      check_resource="true"
    else
      check_resource="false"
    fi

    # Determine if we should skip shutdown based on bastion_required and serviceType
    if [[ $bastion_required == true ]]; then
      if [[ $serviceType == "bastion" ]]; then
        business_area_entry="Cross-Cutting"
        log "Bastion required is: $bastion_required"
        log "Service type is: $serviceType"
        log "Business area set to: $business_area_entry as bastion is required"
        # Compare the list of environments supplied to the function and return common values
        script_env=$(compare_json_lists "$issue_env" "$script_env")
        check_resource="true"
      fi
    fi

    if [[ $check_resource == "false" ]]; then
      continue
    fi

    if [[ ($mode == "stop" || $mode == "deallocate") && $issue_env =~ $script_env && $business_area == $business_area_entry && $(is_in_date_range $start_date $end_date) == "true" ]]; then
      log "Exclusion FOUND"
        if [[ $late_night_run == "false" ]]; then
          log "== 20:00 run =="
          log "skip set to 'true as an exclusion request was found for this resource at the 20:00 run'"
          echo "true"
        elif [[ $late_night_run == "true" && $stay_on_late == "Yes" ]]; then
          log "== 23:00 run =="
          log "skip set to 'true' as an exclusion request was found at 23:00 with 'stay_on_late' var set to $stay_on_late "
          echo "true"
        elif [[ $late_night_run == "true" && $stay_on_late == "No" && $(is_weekend_in_range $start_date $end_date) == "true" && $weekend_day == "true" ]]; then
          log "== 23:00 run =="
          log "skip set to 'true' as an exclusion request was found at 23:00 with 'stay_on_late' var set to $stay_on_late, however shutdown will still be skipped as this is running at the weekend and the environment is required over the weekend."
          echo "true"
        else
          log "defaulting skip var to false"
          echo "false"
        fi
        return
    else
      log "No exclusion found for issue: $issue_number"
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

# Check if a resource is in the business shutdown allowlist
# Usage: is_in_business_shutdown_allowlist [resource_name] [service_type]
# Returns: 0 (success) if resource is in allowlist, 1 (failure) if not
function is_in_business_shutdown_allowlist() {
  local resource_name="$1"
  local service_type="$2"
  local config_file="business_shutdown_config.json"
  
  # If config file doesn't exist, allow all resources (fail-safe)
  if [[ ! -f "$config_file" ]]; then
    log "Business shutdown config file not found - allowing all resources"
    return 0
  fi
  
  # Check if the resource is in the allowlist for this service type
  local in_list=$(jq -r --arg service "$service_type" --arg resource "$resource_name" \
    'if .resources[$service] then (.resources[$service] | map(select(. == $resource)) | length > 0) else false end' \
    "$config_file")
  
  if [[ "$in_list" == "true" ]]; then
    return 0  # Resource is in allowlist
  else
    return 1  # Resource is not in allowlist
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

# Get environment graph query filter
#
# Usage: env_selector [env_selector_param]
#
env_selector() {
    local env="$1"
    if [ -z "$env" ]; then
        echo ""
    elif [ "$env" == "untagged" ]; then
        echo "| where isnull(tags.environment) and isnull(tags.Environment)"
    else
        echo "| where tolower(tags.environment) contains tolower('$env') or tolower(tags.Environment) contains tolower('$env')"
    fi
}

# Get business area graph query filter
#
# Usage: area_selector [business_area_selector_param]
#
area_selector() {
    local area="$1"
    if [ -z "$area" ]; then
        echo ""
    else
        echo "| where tolower(tags.businessArea) == tolower('$area')"
    fi
}
