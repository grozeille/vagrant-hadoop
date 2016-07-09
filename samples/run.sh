#!/bin/bash
DIR=/vagrant

source /etc/bashrc

# test Hive
hdfs dfs -mkdir -p /user/vagrant/rht_quotes

hdfs dfs -put $DIR/samples/rht_quotes.csv /user/vagrant/rht_quotes/

beeline -u jdbc:hive2://hadoop:10000/default -n vagrant -f $DIR/samples/sample_hive.hql

# test Hawq
source /usr/local/hawq/greenplum_path.sh; psql -U gpadmin -p 10432 -h localhost <<EOF
 \d hcatalog.default.*
 \q
EOF

source /usr/local/hawq/greenplum_path.sh; psql -U gpadmin -p 10432 -h localhost -f $DIR/samples/sample_hawq.sql

#hadoop fs -getmerge -nl /user/vagrant/output.csv ./output.csv
#cat ./output.csv | sed 's#\x01# #g' |tail -n +2 |head -n -2 > ./output2.csv

#tsdb import ./output2.csv