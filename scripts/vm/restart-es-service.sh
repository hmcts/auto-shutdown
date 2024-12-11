#!/usr/bin/env bash
# set -x
shopt -s nocasematch

REMOTE_USER="elkadmin"
ENVIRONMENT=$1
PRIVATE_KEY=$2

STAGING_HOSTS=("10.96.149.7" "10.96.149.5" "10.96.149.4" "10.96.149.10")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
DEMO_HOSTS=("10.96.216.4" "10.96.216.7" "10.96.216.5" "10.96.216.6")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
ITHC_HOSTS=("10.112.53.5" "10.112.53.9" "10.112.53.6" "10.112.53.7")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
PERFTEST_HOSTS=("10.112.153.7" "10.112.153.6" "10.112.153.9" "10.112.153.5") # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3

CHECK_COMMAND="sudo systemctl is-failed elasticsearch.service"
RESTART_COMMAND="sudo systemctl restart elasticsearch.service"

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <environment> <private_key>"
  exit 1
fi

case "${ENVIRONMENT}" in
  staging)
    REMOTE_HOSTS=("${STAGING_HOSTS[@]}")
    ;;
  demo)
    REMOTE_HOSTS=("${DEMO_HOSTS[@]}")
    ;;
	ithc)
		REMOTE_HOSTS=("${ITHC_HOSTS[@]}")
		;;
	perftest)
		REMOTE_HOSTS=("${PERFTEST_HOSTS[@]}")
		;;
  *)
    echo "Invalid environment: ${ENVIRONMENT}"
    echo "Environment must be in [staging, demo, ithc, perftest]"
    exit 1
    ;;
esac

for REMOTE_HOST in "${REMOTE_HOSTS[@]}"; do
  STATUS=$(ssh -o ConnectTimeout=20 -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${CHECK_COMMAND}")
	echo $STATUS
  if [[ "${STATUS}" == "active" ]]; then
		echo "Elasticsearch service on ${REMOTE_HOST} is active."
	elif [[ "${STATUS}" == *"Connection timed out"* ]]; then
		echo "Connection to ${REMOTE_HOST} timed out."
	else
		echo "Restarting Elasticsearch service on ${REMOTE_HOST}"
    ssh -o ConnectTimeout=20 -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${RESTART_COMMAND}"
  fi
done