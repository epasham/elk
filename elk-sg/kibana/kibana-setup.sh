#!/bin/bash
#kibana setup 
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#kibana rpm install
rpm -qa | grep kibana-${ELK_VERSION}
[ $? -ne 0 ] && sudo rpm --install ${KB_PKG_URL}

#install search gruad kibana plugin
if [ ! -d "/usr/share/kibana/plugins/searchguard" ]; then
  echo "install kibana searchguard..."
  wget -c ${SG_KB_PKG_URL} -O search-guard-kibana-plugin.zip || (echo "failed to download sg" && exit 209)
  sudo /usr/share/kibana/bin/kibana-plugin install file://$abs_path/search-guard-kibana-plugin.zip
else
  echo "searchguard already exist."
fi
[ ! -d /etc/kibana/certs ] && sudo mkdir /etc/kibana/certs
sudo cp $abs_path/../certs/out/* /etc/kibana/certs
sudo chmod 777 -R /usr/share/kibana/optimize/bundles/*

#prepare log dir
sudo mkdir -p /var/log/kibana/
sudo chown kibana:kibana /var/log/kibana

#config kibana
sudo mv /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bk
sudo touch /etc/kibana/kibana.yml 
sudo tee /etc/kibana/kibana.yml <<FFF
server.port: 5601
server.host: 0.0.0.0
server.name: "${KB_NAME}"
elasticsearch.url: "${ES_API_URL}"
kibana.defaultAppId: "${KB_HOME}"
logging.dest: /var/log/kibana/kibana.log
logging.quiet: true
logging.verbose: false
path.data: ${KB_DATA_PATH}

elasticsearch.username: "${SG_KB_USERNAME}"
elasticsearch.password: "${SG_KB_PASSWORD}"
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/certs/es_http.pem
server.ssl.key: /etc/kibana/certs/es_http.key
elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/root-ca.pem" ]
elasticsearch.ssl.verificationMode: certificate	
FFF

#start kibana service
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service
sudo systemctl restart kibana.service


