#!/bin/bash
shopt -s nocasematch

# Function to convert a string to lowercase
to_lowercase() {
    local input="$1"          
    local lowercase="${input,,}"  # Convert to lowercase using parameter expansion
    echo "$lowercase"
}

function get_clusters() {
    #MS az graph query to find and return a list of all AKS tagged to be included in the auto-shutdown process.
    log "----------------------------------------------"
    log "Running az graph query..."

    if [ -z $1 ]; then
        env_selector=""
    elif [ $1 == "untagged" ]; then
        env_selector="| where isnull(tags.environment)"
    else
        env_selector="| where tags.environment == '$1'"
    fi

    if [ -z $2 ]; then
        area_selector=""
    else
        area_selector="| where tolower(tags.businessArea) == tolower('$2')"
    fi

    az graph query -q "
    resources
    | where type =~ 'Microsoft.ContainerService/managedClusters'
    | where tags.autoShutdown == 'true'
    $env_selector
    $area_selector
    | project name, resourceGroup, subscriptionId, ['tags'], properties, ['id']
    " --first 1000 -o json

    log "az graph query complete"
}

function get_cluster_details() {
    RESOURCE_GROUP=$(jq -r '.resourceGroup' <<<$cluster)
    CLUSTER_NAME=$(jq -r '.name' <<<$cluster)
    STARTUP_MODE=$(jq -r '.tags.startupMode' <<<$cluster)
    CLUSTER_STATUS=$(jq -r '.properties.powerState.code' <<<$cluster)
    SUBSCRIPTION=$(jq -r '.subscriptionId' <<<$cluster)
}

function check_cluster_status() {
    BUSINESS_AREA=$(jq -r '.tags.businessArea' <<<$cluster)
    if [[ "$BUSINESS_AREA" == "Cross-Cutting" ]]; then
        APP="toffee"
    elif [[ "$BUSINESS_AREA" == "CFT" ]]; then
        APP="plum"
    fi

    ENVIRONMENT=$(jq -r '.tags.environment' <<<$cluster)

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

    statuscode=$(curl --max-time 30 --retry 20 --retry-delay 15 -s -o /dev/null -w "%{http_code}" https://$APPLICATION.platform.hmcts.net)

    if [[ ("$ENVIRONMENT" == "demo" || $statuscode -eq 200) ]]; then
        notification "#aks-monitor-$SLACK_CHANNEL_SUFFIX" "$APP works in $ENVIRONMENT after $CLUSTER_NAME start-up"
    else
        message="$APP does not work in $ENVIRONMENT after $CLUSTER_NAME start-up. Please check cluster."
        ts_echo "$message"
        notification "#green-daily-checks" "$message"
        notification "#aks-monitor-$SLACK_CHANNEL_SUFFIX" "$message"
    fi
}

function aks_state_messages() {
    ts_echo_color GREEN "Running $MODE operation on cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
    ts_echo_color GREEN "az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on cluster"
}
