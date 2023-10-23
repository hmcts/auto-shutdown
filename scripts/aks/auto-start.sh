#!/usr/bin/env bash

registrySlackWebhook=$1

function subscription() {
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)
}

function cluster() {
    RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
    NAME=$(jq -r '.name' <<< $cluster)
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

    for variant in "${env_variants[@]}"; do
        parts=(${variant//:/ })
        if [[ "$ENVIRONMENT/$APP" == "${parts[0]}" ]]; then
            APPLICATION="${parts[1]}"
            break
        else
            APPLICATION="$APP.$ENVIRONMENT"
        fi
    done

    ts_echo "Test that $APP works in $ENVIRONMENT after $NAME start-up"

    statuscode=$(curl --max-time 30 --retry 20 --retry-delay 15 -s -o /dev/null -w "%{http_code}"  https://$APPLICATION.platform.hmcts.net)

    if [[ ("$ENVIRONMENT" == "demo" || $statuscode -eq 200) ]]; then
        notification "#aks-monitor-$ENV" "$APP works in $ENVIRONMENT after $NAME start-up"
    else
        message="$APP does not work in $ENVIRONMENT after $NAME start-up. Please check cluster."
        ts_echo "$message"
        notification "#green-daily-checks" "$message"
        notification "#aks-monitor-$ENV" "$message"
    fi
}

function process_clusters() {
    jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
        subscription
        jq -c '.[]' <<< $CLUSTERS | while read cluster; do
            cluster
            ts_echo "About to start cluster $NAME (rg:$RESOURCE_GROUP)"
            az aks start --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors starting cluster $NAME
        done
    done

    echo "Waiting 10 mins to give clusters time to start before testing pods"
    sleep 600

     jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
        subscription
        jq -c '.[]' <<< $CLUSTERS | while read cluster; do
            cluster
            check_cluster_status
            POWER_STATE=$(az aks show --name  $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
            ts_echo "cluster: $NAME, Power State : ${RESULT}"
        done
      done
}

SUBSCRIPTIONS=$(az account list -o json)
process_clusters
