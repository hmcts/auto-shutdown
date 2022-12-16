source './assert.sh'

GLOBAL_DOMAIN="sandbox.platform.hmcts.net"   
    
output=$(curl -s "https://plum.$GLOBAL_DOMAIN/health" | jq -r .status)

assert_eq $output "UP"
if [ "$?" == 0 ]; then
  log_success "assert_eq returns 0 if two words are equal"
else
  log_failure "assert_eq should return 0"
fi
