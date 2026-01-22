-- Migration: Add device configuration and relay status tables
-- Run this migration to support user-specific device management
-- Date: January 22, 2026

-- ============ ADD MISSING COLUMNS TO energy_readings ============
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS voltage FLOAT DEFAULT 0;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS current FLOAT DEFAULT 0;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS energy FLOAT DEFAULT 0;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS power_factor FLOAT DEFAULT 0;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS frequency FLOAT DEFAULT 0;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS temperature FLOAT DEFAULT 0;

-- ============ ADD UNIQUE CONSTRAINT TO USERNAME ============
ALTER TABLE users ADD CONSTRAINT unique_username UNIQUE (username);

-- ============ DEVICE CONFIGURATION TABLE ============
-- Stores device names and relay mappings per user
CREATE TABLE IF NOT EXISTS device_configs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  relay1_name VARCHAR(255) DEFAULT 'Device 1',
  relay2_name VARCHAR(255) DEFAULT 'Device 2',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_device_configs_user
  ON device_configs(user_id);

-- ============ RELAY STATUS TABLE ============
-- Tracks current status of each relay per user
CREATE TABLE IF NOT EXISTS relay_status (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL CHECK (relay_number IN (1, 2)),
  is_on BOOLEAN DEFAULT FALSE,
  last_toggled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, relay_number)
);

CREATE INDEX IF NOT EXISTS idx_relay_status_user
  ON relay_status(user_id);

CREATE INDEX IF NOT EXISTS idx_relay_status_user_relay
  ON relay_status(user_id, relay_number);

-- ============ DEVICE CONTROL LOG TABLE ============
-- Audit trail for device control actions
CREATE TABLE IF NOT EXISTS device_control_logs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL,
  action VARCHAR(50) NOT NULL,
  previous_state BOOLEAN,
  new_state BOOLEAN,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_device_control_logs_user
  ON device_control_logs(user_id, timestamp DESC);

-- ============ USER SESSION TRACKING ============
-- Track which user is currently logged in (for data isolation)
CREATE TABLE IF NOT EXISTS user_sessions (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  session_token VARCHAR(255) UNIQUE NOT NULL,
  device_info VARCHAR(255),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user
  ON user_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_token
  ON user_sessions(session_token);

-- ============ ADD INDEXES FOR ENERGY READINGS ============
CREATE INDEX IF NOT EXISTS idx_energy_readings_user_timestamp
  ON energy_readings(user_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_energy_readings_user_date
  ON energy_readings(user_id, DATE(recorded_at) DESC);

-- ============ ALTER users TABLE IF NEEDED ============
-- This ensures username uniqueness (if not already set)
-- Uncomment if you need to add the constraint
-- ALTER TABLE users ADD CONSTRAINT unique_username UNIQUE (username);

COMMIT;
