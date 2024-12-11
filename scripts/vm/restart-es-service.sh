#!/usr/bin/env bash
# set -x
shopt -s nocasematch

REMOTE_USER="elkadmin"
PRIVATE_KEY="~/.ssh/elk_private_key"

STAGING_HOSTS=("10.96.149.7" "10.96.149.5" "10.96.149.4" "10.96.149.10")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
DEMO_HOSTS=("10.96.216.4" "10.96.216.7" "10.96.216.5" "10.96.216.6")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
ITHC_HOSTS=("10.112.53.5" "10.112.53.9" "10.112.53.6" "10.112.53.7")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
PERFTEST_HOSTS=("10.112.153.7", "10.112.153.6", "10.112.153.9", "10.112.153.5") # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3

CHECK_COMMAND="sudo systemctl is-failed elasticsearch.service"
RESTART_COMMAND="sudo systemctl restart elasticsearch.service"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment>"
  exit 1
fi

ENVIRONMENT=$1

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
  STATUS=$(ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${CHECK_COMMAND}")
  if [ "${STATUS}" != "active" ]; then
		echo "Restarting Elasticsearch service on ${REMOTE_HOST}"
    ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${RESTART_COMMAND}"
  else
    echo "Elasticsearch service on ${REMOTE_HOST} is active."
  fi
done