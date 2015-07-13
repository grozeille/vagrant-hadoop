source /etc/bashrc

nohup $HIVE_HOME/hive --service metastore --hiveconf hive.log.dir=$HIVE_HOME/logs --hiveconf hive.log.file=hive-metastore.log >> logs/hive-metastore.out 2>&1& & 
nohup $HIVE_HOME/hive --service hiveserver2 --hiveconf hive.log.dir=$HIVE_HOME/logs --hiveconf hive.log.file=hive-hiveserver2.log >> logs/hive-hiveserver2.out 2>&1& &