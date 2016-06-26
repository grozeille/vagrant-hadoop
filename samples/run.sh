#!/bin/bash
DIR=/vagrant

source /etc/bashrc

hdfs dfs -mkdir -p /user/vagrant/rht_quotes
hdfs dfs -put $DIR/samples/rht_quotes.csv /user/vagrant/rht_quotes/

beeline -u jdbc:hive2://hadoop:10000/default -n vagrant -f $DIR/samples/create_rht_tables.hql

hadoop fs -getmerge -nl /user/vagrant/output.csv ./output.csv
cat ./output.csv | sed 's#\x01# #g' |tail -n +2 |head -n -2 > ./output2.csv

tsdb import ./output2.csv