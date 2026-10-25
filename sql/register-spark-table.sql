CREATE DATABASE IF NOT EXISTS hw4;

DROP TABLE IF EXISTS hw4.events_summary;

CREATE EXTERNAL TABLE hw4.events_summary (
    event STRING,
    event_count BIGINT,
    distinct_users BIGINT
)
PARTITIONED BY (
    event_date STRING
)
STORED AS PARQUET
LOCATION 'hdfs://team-36-nn:9000/user/team/hw4/events_summary';

MSCK REPAIR TABLE hw4.events_summary;

SHOW PARTITIONS hw4.events_summary;

SELECT *
FROM hw4.events_summary;
