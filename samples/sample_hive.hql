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


select to_date(concat(year(quote_date), '-', month(quote_date), '-01')),close 
from rht_quotes_orc 
limit 10;

select to_date(concat(year(quote_date), '-', month(quote_date), '-01')), sum(volume) as sum_volume, avg(close) as avg_close
from rht_quotes_orc
group by to_date(concat(year(quote_date), '-', month(quote_date), '-01'));