#!/bin/bash
#logstash setup
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#java env setup
$(java -version)
if [ $? -ne 0  ];then
  echo "JDK setup" && sudo  yum install java -y
fi

#logstash rpm install
rpm -qa | grep logstash-${ELK_VERSION}
[ $? -ne 0 ] && sudo rpm --install ${LG_PKG_URL}
sudo [ ! -d /etc/logstash/certs ] && sudo mkdir /etc/logstash/certs
sudo cp $abs_path/../certs/out/* /etc/logstash/certs

#install x-pack
echo "install elasticsearch x-pack..."
sudo /usr/share/logstash/bin/logstash-plugin install x-pack --batch

#config logstash
sudo mv /etc/logstash/logstash.yml /etc/logstash/logstash.yml.bk
sudo tee /etc/logstash/logstash.yml <<FFF
node.name: "${LG_NODE_NAME}"
path.data: "${LG_DATA_PATH}"
path.config: /etc/logstash/conf.d/*.conf
http.host: 0.0.0.0
http.port: 9600-9700
xpack.monitoring.elasticsearch.username: logstash_system
xpack.monitoring.elasticsearch.password: "${LG_PASSWORD}"
xpack.monitoring.enabled: true
xpack.monitoring.elasticsearch.url: ${ES_CLUSTER_API}
xpack.monitoring.elasticsearch.ssl.ca: /etc/logstash/certs/root-ca.pem
path.logs: /var/log/logstash
FFF
sudo cp conf.d/* /etc/logstash/conf.d

#start logstash service
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable logstash.service
sudo systemctl restart logstash.service

