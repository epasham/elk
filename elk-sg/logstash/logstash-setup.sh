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

#config logstash
sudo cp $abs_path/conf.d/* /etc/logstash/conf.d

#start logstash service
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable logstash.service
sudo systemctl restart logstash.service
