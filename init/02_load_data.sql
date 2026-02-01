COPY billboard_inventory
FROM '/data/billboard.csv'
DELIMITER ','
CSV HEADER;

COPY campaign_logs
FROM '/data/campaign_logs.csv'
DELIMITER ','
CSV HEADER;

COPY mobility_events
FROM '/data/mobility.csv'
DELIMITER ','
CSV HEADER;
