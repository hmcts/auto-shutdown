#!/usr/bin/env bash

shopt -s nocasematch
# Source shared function scripts
source scripts/aks/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

CLUSTERS=$(get_clusters)
clusters_count=$(jq -c -r '.count' <<<$CLUSTERS)
log "$clusters_count AKS Clusters found"
log "----------------------------------------------"

jq -c '.data[]' <<<$CLUSTERS | while read cluster; do
# Function that returns the Resource Group, Id and Name of the AKS Cluster and its current state as variables
  get_cluster_details
  cluster_env=$(echo $CLUSTER_NAME | cut -d'-' -f2)

  if [[ $cluster_env == "sbox" ]]; then
    cluster_env=${cluster_env/#sbox/Sandbox}
  elif [[ $cluster_env == "ptlsbox" ]]; then
    cluster_env=${cluster_env/ptlsbox/Sandbox}
  elif [[ $cluster_env == "stg" ]]; then
    cluster_env=${cluster_env/stg/Staging}
  fi

  cluster_business_area=$(echo $CLUSTER_NAME | cut -d'-' -f1)
  cluster_business_area=${cluster_business_area/ss/cross-cutting}

  log "====================================================="
  log "Processing Cluster: $CLUSTER_NAME"
  log "====================================================="

  log "checking skip logic for cluster_env: $cluster_env, cluster_business_area: $cluster_business_area, mode: $MODE"

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $cluster_env $cluster_business_area $MODE "aks")

    # Setup message output templates for later use
    logMessage="SKIP was $SKIP on Cluster: $CLUSTER_NAME in Subscription: $SUBSCRIPTION  ResourceGroup: $RESOURCE_GROUP is in $CLUSTER_STATUS state after $MODE action"
    slackMessage="Cluster: *$CLUSTER_NAME* in Subscription: *$SUBSCRIPTION* is in *$CLUSTER_STATUS* state after *$MODE* action"

    # If SKIP is false then we progress with the status check for the particular AKS Cluster in this loop run, if SKIP is true then do nothing
    if [[ $SKIP == "false" ]]; then
        # Check state of the AKS Cluster and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped AKS Cluster is incorrect and we should notify
        #    - If MODE = Stop then a running AKS Cluster is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        case "$CLUSTER_STATUS" in
        *"Running"*)
            ts_echo_color $([[ $MODE == "start" ]] && echo GREEN || echo RED) "$logMessage"
            if [[ $MODE == "stop" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
            ;;
        *"Stopped"*)
            ts_echo_color $([[ $MODE == "start" ]] && echo RED || echo GREEN) "$logMessage"
            if [[ $MODE == "start" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
            ;;
        *)
            ts_echo_color AMBER "$logMessage"
            auto_shutdown_notification ":yellow_circle: $slackMessage"
            ;;
        esac
    else
        ts_echo_color AMBER "Cluster: $CLUSTER_NAME in ResourceGroup: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
    fi
done
