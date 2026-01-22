// 🗄 FEATURE 2: Store ESP32 Data in PostgreSQL (User-Isolated)
const db = require('../db');
const PowerLimitService = require('./powerLimitService');

class ESP32StorageService {
  // Validate user exists before storing data
  static async validateUser(userId) {
    try {
      const result = await db.query(
        'SELECT id FROM users WHERE id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        throw new Error(`User ${userId} not found`);
      }

      return true;
    } catch (error) {
      console.error('❌ Error validating user:', error);
      throw error;
    }
  }

  // Store ESP32 reading in database (user-isolated)
  static async storeReading(userId, reading) {
    try {
      // Validate user exists
      await this.validateUser(userId);

      // Extract data from ESP32
      const {
        power,
        voltage,
        current,
        energy,
        pf,
        frequency,
        temperature,
        timestamp = new Date()
      } = reading;

      // Validate required fields
      if (power === undefined || power === null) {
        throw new Error('Power value is required');
      }

      // Insert into energy_readings table (only for this user)
      const result = await db.query(
        `INSERT INTO energy_readings 
         (user_id, power_consumption, voltage, current, energy, power_factor, frequency, temperature, recorded_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [userId, power, voltage || 0, current || 0, energy || 0, pf || 0, frequency || 0, temperature || 0, timestamp]
      );

      console.log(`✅ ESP32 reading stored for user ${userId}: P=${power}W V=${voltage}V I=${current}A`);

      // Check power limit and send notifications
      try {
        const settings = await PowerLimitService.getPowerLimitSettings(userId);
        await PowerLimitService.checkPowerLimit(userId, power, settings.daily_power_limit);
      } catch (powerError) {
        console.error('⚠️ Power limit check failed:', powerError.message);
        // Don't fail the main operation
      }

      return result.rows[0];
    } catch (error) {
      console.error('❌ Error storing ESP32 reading:', error);
      throw error;
    }
  }

  // Get latest readings for graph/dashboard (user-specific)
  static async getLatestReadings(userId, limit = 100) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        `SELECT * FROM energy_readings
         WHERE user_id = $1
         ORDER BY recorded_at DESC
         LIMIT $2`,
        [userId, limit]
      );

      return result.rows.reverse(); // Return oldest first for time-series
    } catch (error) {
      console.error('❌ Error fetching readings:', error);
      throw error;
    }
  }

  // Get readings for specific time range (user-specific)
  static async getReadingsByTimeRange(userId, startTime, endTime) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        `SELECT * FROM energy_readings
         WHERE user_id = $1 AND recorded_at >= $2 AND recorded_at <= $3
         ORDER BY recorded_at ASC`,
        [userId, startTime, endTime]
      );

      return result.rows;
    } catch (error) {
      console.error('❌ Error fetching readings by time range:', error);
      throw error;
    }
  }

  // Get hourly statistics (user-specific)
  static async getHourlyStats(userId, date) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        `SELECT 
           DATE_TRUNC('hour', recorded_at) as hour,
           AVG(power_consumption) as avg_power,
           MAX(power_consumption) as peak_power,
           MIN(power_consumption) as min_power,
           SUM(energy) as total_energy,
           COUNT(*) as reading_count
         FROM energy_readings
         WHERE user_id = $1 AND DATE(recorded_at) = $2
         GROUP BY DATE_TRUNC('hour', recorded_at)
         ORDER BY hour ASC`,
        [userId, date]
      );

      return result.rows;
    } catch (error) {
      console.error('❌ Error fetching hourly stats:', error);
      throw error;
    }
  }

  // Get daily summary (user-specific)
  static async getDailySummary(userId, date) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        `SELECT 
           DATE(recorded_at) as date,
           AVG(power_consumption) as avg_power,
           MAX(power_consumption) as peak_power,
           MIN(power_consumption) as min_power,
           SUM(energy) as total_energy,
           AVG(voltage) as avg_voltage,
           AVG(current) as avg_current,
           AVG(power_factor) as avg_pf
         FROM energy_readings
         WHERE user_id = $1 AND DATE(recorded_at) = $2
         GROUP BY DATE(recorded_at)`,
        [userId, date]
      );

      return result.rows[0] || null;
    } catch (error) {
      console.error('❌ Error fetching daily summary:', error);
      throw error;
    }
  }

  // Get user's latest single reading
  static async getLatestReading(userId) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        `SELECT * FROM energy_readings
         WHERE user_id = $1
         ORDER BY recorded_at DESC
         LIMIT 1`,
        [userId]
      );

      return result.rows[0] || null;
    } catch (error) {
      console.error('❌ Error fetching latest reading:', error);
      throw error;
    }
  }

  // Get reading count for user
  static async getReadingCount(userId) {
    try {
      await this.validateUser(userId);

      const result = await db.query(
        'SELECT COUNT(*) as count FROM energy_readings WHERE user_id = $1',
        [userId]
      );

      return parseInt(result.rows[0].count);
    } catch (error) {
      console.error('❌ Error getting reading count:', error);
      throw error;
    }
  }
}

module.exports = ESP32StorageService;
