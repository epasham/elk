#!/bin/bash
#filebeat setup
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#filebeat rpm install
rpm -qa | grep filebeat-${ELK_VERSION}
[ $? -ne 0 ] && sudo rpm --install ${FB_PKG_URL} || (echo "failed to install filebeat" && exit 239)
[ ! -d /etc/filebeat/certs ] && sudo mkdir /etc/filebeat/certs && echo "created filebeat certs dir"
sudo cp $abs_path/../certs/out/* /etc/filebeat/certs/

#load default filebeat template
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable filebeat.service
sudo /bin/systemctl start filebeat.service

sudo filebeat setup --template \
-E output.logstash.enabled=false \
-E output.elasticsearch.hosts=["${ES_API_URL}"] \
-E output.elasticsearch.protocol="https" \
-E output.elasticsearch.username=${SG_ES_USERNAME} \
-E output.elasticsearch.password=${SG_ES_PASSWORD} \
-E output.elasticsearch.ssl.certificate_authorities=["/etc/filebeat/certs/root-ca.pem"] \
-E output.elasticsearch.ssl.certificate="/etc/filebeat/certs/es_http.pem" \
-E output.elasticsearch.ssl.key="/etc/filebeat/certs/es_http.key" \
-E setup.template.settings.index.number_of_routing_shards=${FB_TMPL_ROUT_SHARDS} \
-E setup.template.settings.index.number_of_shards=${FB_TMPL_SHARDS} \
-E setup.template.settings.index.number_of_replicas=${FB_TMPL_REPLICAS} \
-E setup.template.overwrite=true
[ $? -ne 0 ] && echo "faild to load template" && exit 240

#config and start filebeat
sudo mv /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bk
sudo cp $abs_path/filebeat.yml /etc/filebeat/

sudo systemctl restart filebeat


