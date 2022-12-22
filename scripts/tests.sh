#!/usr/bin/env bash

set -e
    
curl -v --fail-with-body https://plum.${ENVIRONMENT}.platform.hmcts.net
