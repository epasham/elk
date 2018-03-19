#!/bin/bash
# set built-in user passwrods

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

grep "set-password" user.txt
if [  $? -ne 0 ];then
  sudo /usr/share/elasticsearch/bin/x-pack/setup-passwords auto -E xpack.security.http.ssl.client_authentication=none --batch > user.txt
  sudo echo "set-password" >> user.txt
else
  echo "The passwords have been initialized."
fi

elastic_password=`grep "elastic =" user.txt |cut -d " " -f 4`
kibana_password=`grep "kibana =" user.txt |cut -d " " -f 4`
logstash_system_password=`grep "logstash_system =" user.txt |cut -d " " -f 4`

#if you want to change the password
curl -XPOST -k -u elastic:${elastic_password} "${ES_API_URL}/_xpack/security/user/elastic/_password?pretty" -H "Content-Type: application/json" -d"{\"password\": \"${ES_PASSWORD}\"}"
curl -XPOST -k -u logstash_system:${logstash_system_password} "${ES_API_URL}/_xpack/security/user/logstash_system/_password?pretty" -H "Content-Type: application/json" -d"{\"password\": \"${LG_PASSWORD}\"}"
curl -XPOST -k -u kibana:${kibana_password} "${ES_API_URL}/_xpack/security/user/kibana/_password?pretty" -H "Content-Type: application/json" -d"{\"password\": \"${KB_PASSWORD}\"}"


