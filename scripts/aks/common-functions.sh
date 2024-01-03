#!/bin/bash

function get_subscription_clusters() {
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_cluster_details() {
    RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
    CLUSTER_NAME=$(jq -r '.name' <<< $cluster)
    STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $cluster)
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
