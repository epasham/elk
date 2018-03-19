#!/bin/bash
#create ca and crt and convert into pkcs8
abs_path=$(cd `dirname $0`; pwd)

$abs_path/tools/sgtlstool.sh -c $abs_path/config/elk.yml -ca -crt -t out

cd $abs_path/out

openssl pkcs8 -topk8 -inform pem -in es.key -outform pem -nocrypt -out es-pk8.key
openssl pkcs8 -topk8 -inform pem -in es_http.key -outform pem -nocrypt -out es_http-pk8.key
openssl pkcs8 -topk8 -inform pem -in sgadmin.key -outform pem -nocrypt -out sgadmin-pk8.key
