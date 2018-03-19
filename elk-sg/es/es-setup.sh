#!/bin/bash
#elasticsearch setup
#OS requirement: redhat 7
set -x

abs_path=$(cd `dirname $0`; pwd)
source $abs_path/../env.conf

#java env setup
$(java -version)
if [ $? -ne 0  ];then
  echo "JDK setup" && sudo  yum install java -y
fi

#elasticsearch rpm instrpm -qa | grep elasticsearch-${verison}
rpm -qa | grep elasticsearch-${ELK_VERSION}
[ $? -ne 0 ] && sudo rpm --install ${ES_PKG_URL}
sudo [ ! -d /etc/elasticsearch/certs ] && sudo mkdir /etc/elasticsearch/certs

#install x-pack
if [ ! -d "/usr/share/elasticsearch/plugins/search-guard-6" ]; then
  echo "install elasticsearch search guard..."
  sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install -b com.floragunn:search-guard-6:${SG_VERSION}
else
  echo "search guard already exist."
fi

#enable es service
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
#sudo systemctl restart elasticsearch.service

