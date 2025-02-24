#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Check and set default MODE if not provided
MODE=${1:-start}

# Convert "stop" to "deallocate"
if [[ "$MODE" == "stop" ]]; then
    MODE="deallocate"
fi

# Validate MODE
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

# Ensure environment and area are set
if [[ -z "$SELECTED_ENV" || -z "$SELECTED_AREA" ]]; then
    echo "Environment or Area not set. Please check your configuration." >&2
    exit 1
fi

# Map environment name to Azure-friendly tag
case "$SELECTED_ENV" in
    "AAT / Staging")
        vmss_env="staging"
        ;;
    "Preview / Dev")
        vmss_env="development"
        ;;
    "Test / Perftest")
        vmss_env="testing"
        ;;
    "PTL")
        vmss_env="production"
        ;;
    "PTLSBOX")
        vvmss_envm_env="sandbox"
        ;;
    *)
        vmss_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac