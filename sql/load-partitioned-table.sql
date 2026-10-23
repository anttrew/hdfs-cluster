CREATE DATABASE IF NOT EXISTS hw3;

DROP TABLE IF EXISTS hw3.events;

CREATE TABLE hw3.events (
    user_id INT,
    event STRING
)
PARTITIONED BY (
    event_date STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

LOAD DATA INPATH '/tmp/hive-hw3/events_2026-10-22.csv'
OVERWRITE INTO TABLE hw3.events
PARTITION (event_date='2026-10-22');

LOAD DATA INPATH '/tmp/hive-hw3/events_2026-10-23.csv'
OVERWRITE INTO TABLE hw3.events
PARTITION (event_date='2026-10-23');

SHOW PARTITIONS hw3.events;

SELECT user_id, event, event_date
FROM hw3.events;
