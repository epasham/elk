# ELK manual setup
---
#### 安装环境: redhat 7.4

Filebeat -> logstash -> elasticearch -> kibana， 使用searchguard或者x-pack启用认证（x-pack认证部分未开源，search guard开源部分支持认证）,filebeat采集hana logs，输出到logstash（2台logstash 负载均衡），grok解析后输出到elasticsearch cluster（3台hosts组建集群并启用用户名密码认证和https），kibana启用tls。

|HOST|filebeat|logstash|elasticsearch|kibana|
|:---|:---|:---|:---|:---|
|10.180.1.76|Y ||||
|10.180.1.83| |Y|Y||
|10.180.1.84| |Y|Y||
|10.180.1.85| ||Y|Y|
---
## 基于searchguard安装
### 1. 生成自签名证书
#### 使用sgtlstool.sh生成自签名证书 [offline tls tool](https://docs.search-guard.com/latest/offline-tls-tool)
1.1 sgtlstool.sh配置文件elk.yml:

````
ca:
   root:
      dn: CN=root.ca,OU=CA,O=SAP,DC=elk,DC=com
      keysize: 2048
      validityDays: 3650
      pkPassword: none
      file: root-ca.pem
defaults:
      validityDays: 3650
      pkPassword: none
      nodeOid: "1.2.3.4.5.5"
      generatedPasswordLength: 12
      httpsEnabled: true
nodes:
  - name: es
    dn: CN=elk,OU=DEVOPS,O=SAP,DC=elk,DC=com
    dns:
      - localhost
      - elk0
      - elk1
      - elk2
      - sportsone-test
    ip:
      - 10.180.1.83
      - 10.180.1.84
      - 10.180.1.85
      - 10.180.1.76
clients:
  - name: sgadmin
    dn: CN=sgadmin,OU=DEVOPS,O=SAP,DC=elk,DC=com
    admin: true
````
1.2 使用sgtlstool生成ca和证书并将密钥转换成pkcs8格式：
````
tools/sgtlstool.sh -c config/elk.yml -ca -crt -t out
openssl pkcs8 -topk8 -inform pem -in es.key -outform pem -nocrypt -out es-pk8.key
openssl pkcs8 -topk8 -inform pem -in es_http.key -outform pem -nocrypt -out es_http-pk8.key
openssl pkcs8 -topk8 -inform pem -in sgadmin.key -outform pem -nocrypt -out sgadmin-pk8.key
````
最终结果：
````
client-certificates.readme           es_http.key  es_http-pk8.key  es.pem      root-ca.key  sgadmin.key  sgadmin-pk8.key
es_elasticsearch_config_snippet.yml  es_http.pem  es.key           es-pk8.key  root-ca.pem  sgadmin.pem
````
1.3 创建certs目录，将生成的所有文件拷贝到/etc/elasticsearch/certs /etc/logstash/certs /etc/kibana/certs /etc/filebeat/certs下备用

*NOTE*：
- sgtlstool将生成ca证书`-ca` es证书以及es_http证书`-crt` `httpsEnabled: true` ,es.pem es.key用于es cluster 传输层加密，es_http.pem es_http.key用于es cluster https和kibana https, es_http-pk8.key es_http.pem用于logstash与filebeat之间加密(logstash启用tls要求密钥为pkcs8格式)。
- ca和key均未启用密码。
- 在dns段加入了所有ip和hostname，这是为了方便将一个证书应用于所有节点，同时生成的证书也可以用于其他services，生产环境建议使用单独的证书。

### 2. 安装elasticsearch
2.1 安装java环境：`sudo yum install java`

2.2 使用rpm包格式安装elasticsearch：
````
ELK_VERSION=6.2.2
ES_PKG_URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELK_VERSION}.rpm
sudo rpm --install ${ES_PKG_URL}
````
2.3 安装elasticsearch searchguard插件
````
SG_VERSION=6.2.2-21.0
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install -b com.floragunn:search-guard-6:${SG_VERSION}
````
2.4 提供es cluster配置文件/etc/elasticsearch/elasticsearch.yml：
````
cluster.name: my-elk
cluster.routing.allocation.enable: all
cluster.routing.allocation.node_concurrent_incoming_recoveries: 2
cluster.routing.allocation.node_concurrent_outgoing_recoveries: 2
cluster.routing.allocation.node_initial_primaries_recoveries: 4
cluster.routing.allocation.same_shard.host: false
cluster.routing.rebalance.enable: all
cluster.routing.allocation.cluster_concurrent_rebalance: 2
node.name: node0
node.master: true
node.data: true
node.ingest: true
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
bootstrap.memory_lock: false
network.host: 0.0.0.0
http.port: 9200
discovery.zen.ping.unicast.hosts: ["10.180.1.83","10.180.1.84","10.180.1.85"]
discovery.zen.ping_timeout: 5s
# Prevent the "split brain" by configuring the majority of nodes (total number of master-eligible nodes / 2 + 1):
discovery.zen.minimum_master_nodes: 2
discovery.zen.no_master_block: all
gateway.recover_after_nodes: 3

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
- CN=sgadmin,OU=DEVOPS,O=SAP,DC=elk,DC=com
searchguard.cert.oid: 1.2.3.4.5.5
````
*NOTE*:
* 在3个es节点均如上操作，注意修改node.name
* `searchguard.cert.oid`如果es node使用单独证书，oid必须相同，或者使用`searchguard.nodes_dn:`指定证书DN.[配置](https://docs.search-guard.com/latest/configuring-tls)
* `searchguard.authcz.admin_dn`客户端证书中包含此DN的，为管理员权限

2.5 初始化searchguard index并启用用户认证。_在es 任意一个节点执行_：[配置](https://docs.search-guard.com/latest/sgadmin)
````
sudo chmod +x /usr/share/elasticsearch/plugins/search-guard-6/tools/sgadmin.sh
sudo /usr/share/elasticsearch/plugins/search-guard-6/tools/sgadmin.sh -cd /usr/share/elasticsearch/plugins/search-guard-6/sgconfig -cn 'my-elk' -nhnv -cacert /etc/elasticsearch/certs/root-ca.pem -cert /etc/elasticsearch/certs/sgadmin.pem -key /etc/elasticsearch/certs/sgadmin-pk8.key
````
- sgadmin.sh默认cluster.name为elasticsearch，`-cn`指定为my-elk。默认admin用户名密码为admin/admin
- 通过`/usr/share/elasticsearch/plugins/search-guard-6/tools/hash.sh`生成密码hash，配置于`/usr/share/elasticsearch/plugins/search-guard-6/sgconfig/sg_internal_users.yml`中，用户密码及role保存于：`/usr/share/elasticsearch/plugins/search-guard-6/sgconfig`目录中。
- [常见故障](https://docs.search-guard.com/latest/troubleshooting-sgadmin)

2.6 启动es
````
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
sudo systemctl restart elasticsearch.service
````
2.7 验证集群状态
- 查看默认生成的用户名和密码:

````
cat /usr/share/elasticsearch/plugins/search-guard-6/sgconfig/sg_internal_users.yml

# This is the internal user database
# The hash value is a bcrypt hash and can be generated with plugin/tools/hash.sh

#password is: admin
admin:
  readonly: true
  hash: $2a$12$VcCDgh2NDk07JGN0rjGbM.Ad41qVR/YFJcgHp0UGns5JDymv..TOG
  roles:
    - admin
  attributes:
    #no dots allowed in attribute names
    attribute1: value1
    attribute2: value2
    attribute3: value3

#password is: logstash
logstash:
  hash: $2a$12$u1ShR4l4uBS3Uv59Pa2y5.1uQuZBrZtmNfqB3iM/.jL0XoV9sghS2
  roles:
    - logstash

#password is: kibanaserver
kibanaserver:
  readonly: true
  hash: $2a$12$4AcgAt3xwOWadA5s5blL6ev39OXDNhmOesEoo33eZtrq2N0YrU3H.

#password is: kibanaro
kibanaro:
  hash: $2a$12$JJSXNfTowz7Uu5ttXfeYpeYE0arACvcwlPBStB1F.MI7f0U9Z4DGC
  roles:
    - kibanauser
    - readall

#password is: readall
readall:
  hash: $2a$12$ae4ycwzwvLtZxwZ82RmiEunBbIPiAmGZduBAjKN0TXdwQFtCwARz2
  #password is: readall
  roles:
    - readall

#password is: snapshotrestore
snapshotrestore:
  hash: $2y$12$DpwmetHKwgYnorbgdvORCenv4NAK8cPUg8AI6pxLCuWf/ALc0.v7W
  roles:
    - snapshotrestore
````
- 查看集群健康状态：

````
ES_API_URL="https://10.180.1.83:9200"
curl -XGET "${ES_API_URL}/_cat/health?v&pretty" -u admin:admin -k
epoch      timestamp cluster status node.total node.data shards pri relo init unassign pending_tasks max_task_wait_time active_shards_percent
1521450826 09:13:46  my-elk  green           3         3     41  14    0    0        0             0                  -                100.0%
````
### 3. 安装kibana
3.1 安装kibana rpm包
````
ELK_VERSION=6.2.2
KB_PKG_URL=https://artifacts.elastic.co/downloads/kibana/kibana-${ELK_VERSION}-x86_64.rpm
sudo rpm --install ${KB_PKG_URL}
#prepare log dir
sudo mkdir -p /var/log/kibana/
sudo chown kibana:kibana /var/log/kibana
````
3.2 下载并安装kibana searchguard插件
````
SG_KB_PKG_URL=https://search.maven.org/remotecontent?filepath=com/floragunn/search-guard-kibana-plugin/6.2.2-10/search-guard-kibana-plugin-6.2.2-10.zip
wget -c ${SG_KB_PKG_URL} -O search-guard-kibana-plugin.zip
sudo /usr/share/kibana/bin/kibana-plugin install file:///home/ccloud/elk-sg/search-guard-kibana-plugin.zip
sudo chmod 777 -R /usr/share/kibana/optimize/bundles/*
````
3.3 提供/etc/kibana.yml配置文件
````
server.port: 5601
server.host: 0.0.0.0
server.name: "elk"
elasticsearch.url: "https://10.180.1.83:9200"
kibana.defaultAppId: "home"
logging.dest: /var/log/kibana/kibana.log
logging.quiet: true
logging.verbose: false
path.data: /var/lib/kibana

elasticsearch.username: "kibanaserver"
elasticsearch.password: "kibanaserver"
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/certs/es_http.pem
server.ssl.key: /etc/kibana/certs/es_http.key
elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/root-ca.pem" ]
elasticsearch.ssl.verificationMode: certificate
````
*`elasticsearch.username`和`elasticsearch.password`为es 初始化searchguard index时默认的用户名和密码*

3.4 启动kibana
````
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service
sudo systemctl restart kibana.service
````

### 4. 安装logstash
4.1 安装logstash rpm包
````
ELK_VERSION=6.2.2
LG_PKG_URL="https://artifacts.elastic.co/downloads/logstash/logstash-${ELK_VERSION}.rpm"
sudo rpm --install ${LG_PKG_URL}

````
4.2 在/etc/logstash/conf.d下提供beat-input.conf配置文件
````
input {
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/logstash/certs/es_http.pem"
    ssl_key => "/etc/logstash/certs/es_http-pk8.key"
    ssl_certificate_authorities => "/etc/logstash/certs/root-ca.pem"
    ssl_verify_mode => none
  }
}

filter {
  if "hana-srv" in [tags] {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:HANAtimestamp}\s%{WORD:LOGLEVEL}\s%{WORD:ACTION}\s+%{GREEDYDATA:CONTENT}" }
    }
  }

  if "hana-available" in [tags] {
    grok {
      match => { "message" => "%{WORD:HANASTATUS}\s+%{DATESTAMP:CHANGETIME}\s-\s%{DATESTAMP}" }
    }
  }
}

output {
  if "hana-srv" in [tags] {
    elasticsearch {
      hosts => ["10.180.1.83:9200", "10.180.1.84:9200", "10.180.1.85:9200"]
      user => admin
      password => admin
      ssl => true
      ssl_certificate_verification => true
      cacert => "/etc/logstash/certs/root-ca.pem"
      manage_template => false
      index => "filebeat-6.2.2-hana-services-%{+YYYY.MM.dd}"
    }
  }

  if "hana-available" in [tags] {
    elasticsearch {
      hosts => ["10.180.1.83:9200", "10.180.1.84:9200", "10.180.1.85:9200"]
      user => admin
      password => admin
      ssl => true
      ssl_certificate_verification => true
      cacert => "/etc/logstash/certs/root-ca.pem"
      manage_template => false
      index => "filebeat-6.2.2-hana-available-%{+YYYY.MM.dd}"
    }
  }
}
````
2台logstash使用相同配置

4.3 启动logstash
````
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable logstash.service
sudo systemctl restart logstash.service
````
*NOTE* :日志解析表达式编写：http://grokdebug.herokuapp.com/

### 5 filebeat安装
5.1 filebeat rpm包安装，采集hana日志
````
ELK_VERSION=6.2.2
FB_PKG_URL=https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${ELK_VERSION}-x86_64.rpm
sudo rpm --install ${FB_PKG_URL}
````
5.2 es启用filebeat的template

filebeat通过logstash输入解析日志到es,需要在es启用filebeat的template, shards需要在此时指定，index生成后不能再修改shards，除非所有数据re-shared
````
ES_API_URL="https://10.180.1.83:9200"
SG_ES_USERNAME="admin"
SG_ES_PASSWORD="admin"
FB_TMPL_SHARDS=6
FB_TMPL_REPLICAS=2
FB_TMPL_ROUT_SHARDS=36

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
````
*TIPS* ：如果将es看作是一个数据库，那么按照对数据库的理解，es在存储数据时首先需要创建表，然后存储数据，那么index相当于表的实例，多个index组成indices, field则是表的列名。那表的列是如何定义的呢？es如何知道哪些列是什么数据类型呢？这就需要使用mapping定义，另外还需要定义数据的分片(number_of_shards),以及数据的备份数(number_of_replicas)等，这些mapping,setting等是es根据template创建的。Es默认提供logstash和kibana的template，如果使用filebeat传入logstash再传入es，那么需要定义filebeat适用的template。上面的设置是使用的默认logstash template，默认的shards是5，replicas是1。如果需要将shard调整其他值，那么需要在filebeat的template中配置并在es中指定使用此template， replias可以可以在创建后修改，但数量应小于node数量，否则会出现replias没有节点可以指派，,注意：要使用es中的template，那在指定index时需要包含在template名内，例如template名为filebeat-6.2.2，如果要使用该template，index应指定为filebeat-6.2.2-*

5.3 提供filebeat.yml配置文件:/etc/filebeat/filebeat.yml
````
filebeat.prospectors:
- type: log
  enabled: true
  paths:
    - /usr/sap/SP1/HDB00/sportsone-test/trace/available.log
  tags: ["hana-available"]
- type: log
  enabled: true
  paths:
    - /usr/sap/SP1/HDB00/sportsone-test/trace/indexserver*.trc
  tags: ["hana-indexserver","hana-srv"]
  exclude_files: ['\.executed_statements','\.loads','\.unloads']
- type: log
  enabled: true
  paths:
    - /usr/sap/SP1/HDB00/sportsone-test/trace/xsengine*.trc
  tags: ["hana-xsengine","hana-srv"]
  exclude_files: ['\.executed_statements']
- type: log
  enabled: true
  paths:
    - /usr/sap/SP1/HDB00/sportsone-test/trace/webdispatcher*.trc
  tags: ["hana-webdispatcher","hana-srv"]
  exclude_files: ['\.dev']
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
output.logstash:
  hosts: ["10.180.1.83:5044", "10.180.1.84:5044"]
  loadbalance: true
  ssl.certificate_authorities: ["/etc/filebeat/certs/root-ca.pem"]
  ssl.certificate: "/etc/filebeat/certs/es_http.pem"
  ssl.key: "/etc/filebeat/certs/es_http.key"
````
5.4 启动filebeat
````
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable filebeat.service
sudo /bin/systemctl restart filebeat.service
````

### 6 验证elk-sg
6.1 登陆kibana
![login](https://github.com/facewy/elk/raw/master/screenshots/kibana1.png)
6.2 查看filebeat template

6.3 查看发现的日志
