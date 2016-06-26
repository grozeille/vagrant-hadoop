CREATE EXTERNAL TABLE IF NOT EXISTS rht_quotes(
        Quote_Date DATE, 
        Open DOUBLE,
        High DOUBLE,
        Low DOUBLE,
        Close DOUBLE,
        Volume DOUBLE,
        Adj_Close DOUBLE)
    COMMENT 'Data from Yahoo finance for RHL (RedHat)'
    ROW FORMAT DELIMITED
    FIELDS TERMINATED BY ','
    STORED AS TEXTFILE
    location '/user/vagrant/rht_quotes';

CREATE TABLE IF NOT EXISTS rht_quotes_orc 
    STORED AS ORC
    AS
    SELECT quote_date, open, high, low, close, volume, adj_close FROM rht_quotes;

select year(quote_date) as year, month(quote_date) as month, avg(adj_close) as avg_adj_close from rht_quotes group by year(quote_date), month(quote_date);

SET hive.aux.jars.path = file:///etc/hbase/conf/hbase-site.xml,file:///usr/lib/hive/lib/hive-hbase-handler-0.11.0.1.3.2.0-111.jar,file:///usr/lib/hbase/hbase-0.94.6.1.3.2.0-111-security.jar,file:///usr/lib/zookeeper/zookeeper-3.4.5.1.3.2.0-111.jar;

CREATE TABLE IF NOT EXISTS pagecounts_hbase (rowkey STRING, pageviews STRING, bytes STRING)
STORED BY ‘org.apache.hadoop.hive.hbase.HBaseStorageHandler’
WITH SERDEPROPERTIES (‘hbase.columns.mapping’ = ‘:key,f:c1,f:c2’)
TBLPROPERTIES (‘hbase.table.name’ = ‘pagecounts’);


insert overwrite directory '/user/vagrant/output.csv'
select 'quote.close' as metric, unix_timestamp(quote_date) as metric_timestamp,close,concat('symbol=','RHL') as tags from rht_quotes_orc order by metric_timestamp ASC;