#!/bin/bash

abs_path=$(cd `dirname $0`; pwd)

$abs_path/tools/sgtlstool.sh -c $abs_path/config/csr.yml -csr -t csr
