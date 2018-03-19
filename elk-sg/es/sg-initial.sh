#!/bin/bash
#search guard initialize

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

sudo chmod +x /usr/share/elasticsearch/plugins/search-guard-6/tools/sgadmin.sh

sudo /usr/share/elasticsearch/plugins/search-guard-6/tools/sgadmin.sh -cd /usr/share/elasticsearch/plugins/search-guard-6/sgconfig -cn ${ES_CLUSTER_NAME} -nhnv -cacert /etc/elasticsearch/certs/root-ca.pem -cert /etc/elasticsearch/certs/sgadmin.pem -key /etc/elasticsearch/certs/sgadmin-pk8.key

#verify initialize
res=`curl -XGET "${ES_API_URL}/_cat/health?v&pretty" -u admin:admin -k`
echo $res | grep green
if [ $? -ne 0 ];then
  echo "failed to sgadmin initialize"
  exit 211
fi
