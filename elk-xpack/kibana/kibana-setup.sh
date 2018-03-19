#!/bin/bash
#kibana setup 
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#kibana rpm install
rpm -qa | grep kibana-${ELK_VERSION}
[ $? -ne 0 ] && sudo rpm --install ${KB_PKG_URL}

#install x-pack
if [ ! -d "/usr/share/kibana/plugins/x-pack" ]; then
  echo "install kibana x-pack..."
  sudo /usr/share/kibana/bin/kibana-plugin install x-pack -q
else
  echo "x-pack already exist."
fi
[ ! -d /etc/kibana/certs ] && sudo mkdir /etc/kibana/certs
sudo cp $abs_path/../certs/out/* /etc/kibana/certs

#config kibana
sudo mv /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bk
sudo touch /etc/kibana/kibana.yml 
sudo tee /etc/kibana/kibana.yml <<FFF
server.port: 5601
server.host: 0.0.0.0
server.name: "${KB_NAME}"
elasticsearch.url: "${ES_API_URL}"
kibana.defaultAppId: "${KB_HOME}"
elasticsearch.username: kibana
elasticsearch.password: "${KB_PASSWORD}"
xpack.security.enabled: true
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/certs/es_http.pem
server.ssl.key: /etc/kibana/certs/es_http.key
elasticsearch.ssl.certificate: /etc/kibana/certs/es_http.pem
elasticsearch.ssl.key: /etc/kibana/certs/es_http.key
elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/root-ca.pem" ]
elasticsearch.ssl.verificationMode: none
FFF

#start kibana service
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service
sudo systemctl restart kibana.service


