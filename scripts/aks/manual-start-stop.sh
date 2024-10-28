#!/usr/bin/env bash

# Source common functions
source scripts/aks/common-functions.sh
source scripts/common/common-functions.sh

# Enable case-insensitive matching
shopt -s nocasematch

# Check and set default MODE if not provided
MODE=${1:-start}

# Ensure valid MODE
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'." >&2
    exit 1
fi

# Ensure SELECTED_ENV and SELECTED_AREA are set
if [[ -z "$SELECTED_ENV" || -z "$SELECTED_AREA" ]]; then
    echo "Environment or Area not set. Please check your configuration." >&2
    exit 1
fi

# Map the environment name to match Azure enviornment tag
case "$SELECTED_ENV" in
    "AAT / Staging")
        cluster_env="staging"
        ;;
    "Preview / Dev")
        cluster_env="development"
        ;;
    "Test / Perftest")
        cluster_env="testing"
        ;;
    "PTL")
        cluster_env="production"
        ;;
    "PTLSBOX")
        cluster_env="sandbox"
        ;;
    *)
        cluster_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the cluster area if necessary
cluster_area="$SELECTED_AREA"
if [[ "$cluster_area" == "SDS" ]]; then
    cluster_area="Cross-Cutting"
fi

# Retrieve clusters based on environment and area
CLUSTERS=$(get_clusters "$cluster_env" "$cluster_area")
clusters_count=$(jq -c -r '.count' <<<$CLUSTERS)
if [[ $clusters_count -eq 0 ]]; then
    echo "No clusters found for environment: $cluster_env and area: $cluster_area." >&2
    exit 1
fi

# Iterate over clusters
jq -c '.data[]' <<< "$CLUSTERS" | while read -r cluster; do
    get_cluster_details  # Assuming this function processes individual clusters

    log "================================================================================"
    log "Processing Cluster: $CLUSTER_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"
    log "================================================================================"

    if [[ "$DEV_ENV" != "true" ]]; then
        aks_state_messages  # Function for displaying state messages
        # Perform the desired operation (start/stop) on the cluster
        if ! az aks "$MODE" --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --subscription "$SUBSCRIPTION" --no-wait; then
            echo "Ignoring any errors while performing $MODE operation on cluster: $CLUSTER_NAME" >&2
        fi
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        aks_state_messages
    fi

    # Get the cluster power state after the operation
    RESULT=$(az aks show --name "$CLUSTER_NAME" -g "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION" | jq -r .powerState.code)
    ts_echo "Cluster $CLUSTER_NAME is in state: $RESULT"
done
