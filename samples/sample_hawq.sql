select to_date(extract(year from quote_date) || extract(month from  quote_date), 'YYYYMM') , close 
from hcatalog.default.rht_quotes_orc 
limit 10;

select to_date(extract(year from quote_date) || extract(month from  quote_date), 'YYYYMM') , sum(volume) as sum_volume, avg(close) as avg_close
from hcatalog.default.rht_quotes_orc 
group by to_date(extract(year from quote_date) || extract(month from  quote_date), 'YYYYMM');



