#!/bin/bash

function get_subscription_clusters() {
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_cluster_details() {
    RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
    CLUSTER_NAME=$(jq -r '.name' <<< $cluster)
    CLUSTER_STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $cluster)
}

function ts_echo() {
    date +"%H:%M:%S $(printf "%s "  "$@")"
}

function notification() {
    local channel="$1"
    local message="$2"
    curl -X POST --data-urlencode "payload={\"channel\": \"$channel\", \"username\": \"AKS Auto-Start\", \"text\": \"$message\", \"icon_emoji\": \":tim-webster:\"}" \
        ${registrySlackWebhook}
}

function check_cluster_status() {
    BUSINESS_AREA=$(jq -r '.tags.businessArea' <<< $cluster)
    if [[ "$BUSINESS_AREA" == "Cross-Cutting" ]]; then
        APP="toffee"
    elif [[ "$BUSINESS_AREA" == "CFT" ]]; then
        APP="plum"
    fi

    ENVIRONMENT=$(jq -r '.tags.environment' <<< $cluster)

    local env_variants=(
        "sandbox/Sandbox:sbox"
        "testing/toffee:toffee.test"
        "testing/plum:plum.perftest"
        "staging/toffee:toffee.staging"
        "staging/plum:plum.aat"
    )

    local -A notify_channel_map=(
      [sandbox]="sbox"
      [testing]="perftest"
      [staging]="aat"
    )

    if [ -n "${notify_channel_map[$ENVIRONMENT]}" ]; then
      SLACK_CHANNEL_SUFFIX="${notify_channel_map[$ENVIRONMENT]}"
    else
      SLACK_CHANNEL_SUFFIX="$ENVIRONMENT"
    fi

    for variant in "${env_variants[@]}"; do
        parts=(${variant//:/ })
        if [[ "$ENVIRONMENT/$APP" == "${parts[0]}" ]]; then
            APPLICATION="${parts[1]}"
            break
        else
            APPLICATION="$APP.$ENVIRONMENT"
        fi
    done

    ts_echo "Test that $APP works in $ENVIRONMENT after $CLUSTER_NAME start-up"

    statuscode=$(curl --max-time 30 --retry 20 --retry-delay 15 -s -o /dev/null -w "%{http_code}"  https://$APPLICATION.platform.hmcts.net)

    if [[ ("$ENVIRONMENT" == "demo" || $statuscode -eq 200) ]]; then
        notification "#aks-monitor-$SLACK_CHANNEL_SUFFIX" "$APP works in $ENVIRONMENT after $CLUSTER_NAME start-up"
    else
        message="$APP does not work in $ENVIRONMENT after $CLUSTER_NAME start-up. Please check cluster."
        ts_echo "$message"
        notification "#green-daily-checks" "$message"
        notification "#aks-monitor-$SLACK_CHANNEL_SUFFIX" "$message"
    fi
}

function get_current_date_seconds() {
  local current_date_formatting
  current_date_formatting=$(date +'%Y-%m-%d')
  date -d "$current_date_formatting 00:00:00" +%s
}

function is_in_date_range() {
  local start_date_seconds end_date_seconds current_date_seconds
  start_date_seconds=$(date -d "$1 00:00:00" +%s)
  end_date_seconds=$(date -d "$2 00:00:00" +%s)
  current_date_seconds=$(get_current_date_seconds)

  if [[ $current_date_seconds -ge $start_date_seconds && $current_date_seconds -le $end_date_seconds ]]; then
    echo "true"
  else
    echo "false"
  fi
}

function should_skip_start_stop () {
  local cluster_env cluster_business_area issue
  cluster_env=$1
  cluster_business_area=$2
  mode=$3
  while read issue; do
    local env_entry business_area_entry start_date end_date
    env_entry=$(jq -r '."environment"' <<< $issue)
    business_area_entry=$(jq -r '."business_area"' <<< $issue)
    start_date=$(jq -r '."skip_start_date"' <<< $issue)
    end_date=$(jq -r '."skip_end_date"' <<< $issue)
    get_request_type $issue

    if [[ $request_type != $mode ]]; then
      continue
    fi
    if [[ $CLUSTER_STARTUP_MODE != "onDemand" && $request_type == "start" ]]; then
      continue
    fi
    if [[ $env_entry =~ $cluster_env && $cluster_business_area == $business_area_entry ]]; then
      if [[ $start_date == $(date +'%d-%m-%Y') ]]; then
        continue
      fi
      if [[ $(is_in_date_range $start_date $end_date) == "true" ]]; then
        continue
      fi
    fi
  done < <(jq -c '.[]' issues_list.json)

  echo "false"
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