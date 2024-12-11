#!/usr/bin/env bash
# set -x
shopt -s nocasematch

REMOTE_USER="elkadmin"
PRIVATE_KEY="~/.ssh/elk_private_key"
REMOTE_HOSTS=("10.96.149.7" "10.96.149.5" "10.96.149.4" "10.96.149.10")  # ccd-data-0, ccd-data-1, ccd-data-2, ccd-data-3
CHECK_COMMAND="sudo systemctl is-failed elasticsearch.service"
RESTART_COMMAND="sudo systemctl restart elasticsearch.service"

for REMOTE_HOST in "${REMOTE_HOSTS[@]}"; do
  STATUS=$(ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${CHECK_COMMAND}")
  if [ "${STATUS}" != "active" ]; then
    ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" ${REMOTE_USER}@${REMOTE_HOST} "${RESTART_COMMAND}"
  else
    echo "Elasticsearch service on ${REMOTE_HOST} is active."
  fi
done