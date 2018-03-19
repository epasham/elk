#!/bin/bash
#elasticsearch cluster node setup 
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#copy crets
sudo cp $abs_path/../certs/out/* /etc/elasticsearch/certs

#config es cluster
let node_num=`echo ${ES_CLUSTER_HOSTS} | grep -o , |wc -l`+1
sudo mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bk
sudo touch /etc/elasticsearch/elasticsearch.yml
sudo tee /etc/elasticsearch/elasticsearch.yml <<FFF
cluster.name: ${ES_CLUSTER_NAME}
cluster.routing.allocation.enable: all
cluster.routing.allocation.node_concurrent_incoming_recoveries: 2
cluster.routing.allocation.node_concurrent_outgoing_recoveries: 2
cluster.routing.allocation.node_initial_primaries_recoveries: 4
cluster.routing.allocation.same_shard.host: false
cluster.routing.rebalance.enable: all
cluster.routing.allocation.cluster_concurrent_rebalance: 2
node.name: ${ES_NODE_NAME}
node.master: true
node.data: true
node.ingest: true
path.data: ${ES_DATA_PATH}
path.logs: /var/log/elasticsearch
bootstrap.memory_lock: false
network.host: 0.0.0.0
http.port: 9200
discovery.zen.ping.unicast.hosts: ${ES_CLUSTER_HOSTS}
discovery.zen.ping_timeout: 5s
# Prevent the "split brain" by configuring the majority of nodes (total number of master-eligible nodes / 2 + 1):
discovery.zen.minimum_master_nodes: `echo $[$node_num/2+1]`
discovery.zen.no_master_block: all
gateway.recover_after_nodes: $node_num

searchguard.enterprise_modules_enabled: false
searchguard.ssl.transport.pemcert_filepath: certs/es.pem
searchguard.ssl.transport.pemkey_filepath: certs/es-pk8.key
#searchguard.ssl.transport.pemkey_password: wUYuY4Bb8pbR
searchguard.ssl.transport.pemtrustedcas_filepath: certs/root-ca.pem
searchguard.ssl.transport.enforce_hostname_verification: false
searchguard.ssl.transport.resolve_hostname: false
searchguard.ssl.http.enabled: true
searchguard.ssl.http.pemcert_filepath: certs/es_http.pem
searchguard.ssl.http.pemkey_filepath: certs/es_http-pk8.key
#searchguard.ssl.http.pemkey_password: gkz1cGYgfkXZ
searchguard.ssl.http.pemtrustedcas_filepath: certs/root-ca.pem
searchguard.authcz.admin_dn:
- ${SG_ADMIN_DN} 
searchguard.cert.oid: ${SG_OID}
FFF

#start es service
sudo systemctl restart elasticsearch.service

