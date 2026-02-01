-- Billboard Inventory
CREATE TABLE billboard_inventory (
    billboard_id VARCHAR(50) PRIMARY KEY,
    billboard_name VARCHAR(255) NOT NULL,
    city VARCHAR(100),
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    size VARCHAR(20) CHECK (size IN ('Small', 'Medium', 'Large')),
    daily_cost INTEGER DEFAULT 0,
    traffic_score INTEGER CHECK (traffic_score BETWEEN 1 AND 100)
);

-- Mobility Events
-- Tabel ini biasanya sangat besar, disarankan menggunakan indexing pada device_id dan timestamp
CREATE TABLE mobility_events (
    event_id VARCHAR(50) PRIMARY KEY,
    device_id VARCHAR(100) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    city VARCHAR(100)
);

-- 3. Tabel Transaksi: Campaign Exposure Logs
CREATE TABLE campaign_logs (
    log_id VARCHAR(50) PRIMARY KEY,
    campaign_id VARCHAR(50) NOT NULL,
    billboard_id VARCHAR(50) NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    exposure_time TIMESTAMP NOT NULL,
    
    -- Penambahan Foreign Key untuk Integritas Data
    CONSTRAINT fk_billboard 
        FOREIGN KEY (billboard_id) 
        REFERENCES billboard_inventory(billboard_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_logs_campaign ON campaign_logs(campaign_id);