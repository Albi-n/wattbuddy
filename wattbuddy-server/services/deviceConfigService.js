// 🔌 Device Configuration Service
// Manages device names, relay status, and control

const db = require('../db');

class DeviceConfigService {
  // ============ GET DEVICE CONFIGURATION ============
  static async getDeviceConfig(userId) {
    try {
      let result = await db.query(
        `SELECT * FROM device_configs WHERE user_id = $1`,
        [userId]
      );

      // If no config exists, create one automatically
      if (result.rows.length === 0) {
        console.log(`⚠️ Device config not found for user ${userId}, creating...`);
        result = await db.query(
          `INSERT INTO device_configs (user_id, relay1_name, relay2_name)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id) DO UPDATE SET relay1_name = EXCLUDED.relay1_name
           RETURNING *`,
          [userId, 'Device 1', 'Device 2']
        );
      }

      return result.rows[0];
    } catch (error) {
      console.error('❌ Error fetching device config:', error);
      throw error;
    }
  }

  // ============ INITIALIZE DEVICE CONFIG (Called on user registration) ============
  static async initializeDeviceConfig(userId) {
    try {
      const result = await db.query(
        `INSERT INTO device_configs (user_id, relay1_name, relay2_name)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [userId, 'Device 1', 'Device 2']
      );

      console.log(`✅ Device config initialized for user ${userId}`);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error initializing device config:', error);
      throw error;
    }
  }

  // ============ UPDATE DEVICE NAMES ============
  static async updateDeviceNames(userId, relay1Name, relay2Name) {
    try {
      const result = await db.query(
        `UPDATE device_configs 
         SET relay1_name = $1, relay2_name = $2, updated_at = NOW()
         WHERE user_id = $3
         RETURNING *`,
        [relay1Name, relay2Name, userId]
      );

      if (result.rows.length === 0) {
        throw new Error('Device configuration not found');
      }

      console.log(`✅ Device names updated for user ${userId}`);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error updating device names:', error);
      throw error;
    }
  }

  // ============ GET RELAY STATUS ============
  static async getRelayStatus(userId, relayNumber) {
    try {
      const result = await db.query(
        `SELECT * FROM relay_status 
         WHERE user_id = $1 AND relay_number = $2`,
        [userId, relayNumber]
      );

      if (result.rows.length === 0) {
        // If not found, initialize it
        return await this.initializeRelayStatus(userId, relayNumber);
      }

      return result.rows[0];
    } catch (error) {
      console.error('❌ Error fetching relay status:', error);
      throw error;
    }
  }

  // ============ GET ALL RELAY STATUS FOR USER ============
  static async getAllRelayStatus(userId) {
    try {
      let result = await db.query(
        `SELECT relay_number, is_on, last_toggled_at 
         FROM relay_status 
         WHERE user_id = $1 
         ORDER BY relay_number ASC`,
        [userId]
      );

      // If no relays exist, create them
      if (result.rows.length === 0) {
        console.log(`⚠️ Relay status not found for user ${userId}, initializing...`);
        await this.initializeAllRelays(userId);
        
        result = await db.query(
          `SELECT relay_number, is_on, last_toggled_at 
           FROM relay_status 
           WHERE user_id = $1 
           ORDER BY relay_number ASC`,
          [userId]
        );
      }

      return result.rows;
    } catch (error) {
      console.error('❌ Error fetching all relay status:', error);
      throw error;
    }
  }

  // ============ INITIALIZE RELAY STATUS (Called on user registration) ============
  static async initializeRelayStatus(userId, relayNumber) {
    try {
      const result = await db.query(
        `INSERT INTO relay_status (user_id, relay_number, is_on)
         VALUES ($1, $2, $3)
         ON CONFLICT (user_id, relay_number) DO UPDATE 
         SET is_on = EXCLUDED.is_on
         RETURNING *`,
        [userId, relayNumber, false]
      );

      console.log(`✅ Relay ${relayNumber} status initialized for user ${userId}`);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error initializing relay status:', error);
      throw error;
    }
  }

  // ============ TOGGLE RELAY ============
  static async toggleRelay(userId, relayNumber) {
    try {
      // Get current status
      const currentStatus = await this.getRelayStatus(userId, relayNumber);
      const newState = !currentStatus.is_on;

      // Update status
      const result = await db.query(
        `UPDATE relay_status 
         SET is_on = $1, last_toggled_at = NOW()
         WHERE user_id = $2 AND relay_number = $3
         RETURNING *`,
        [newState, userId, relayNumber]
      );

      // Log the action
      await this.logDeviceControl(userId, relayNumber, 'toggle', currentStatus.is_on, newState);

      console.log(`✅ Relay ${relayNumber} toggled to ${newState ? 'ON' : 'OFF'} for user ${userId}`);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error toggling relay:', error);
      throw error;
    }
  }

  // ============ SET RELAY STATE ============
  static async setRelayState(userId, relayNumber, state) {
    try {
      // Get current status
      const currentStatus = await this.getRelayStatus(userId, relayNumber);

      // Update status
      const result = await db.query(
        `UPDATE relay_status 
         SET is_on = $1, last_toggled_at = NOW()
         WHERE user_id = $2 AND relay_number = $3
         RETURNING *`,
        [state, userId, relayNumber]
      );

      // Log the action
      await this.logDeviceControl(userId, relayNumber, state ? 'ON' : 'OFF', currentStatus.is_on, state);

      console.log(`✅ Relay ${relayNumber} set to ${state ? 'ON' : 'OFF'} for user ${userId}`);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error setting relay state:', error);
      throw error;
    }
  }

  // ============ LOG DEVICE CONTROL ACTION ============
  static async logDeviceControl(userId, relayNumber, action, previousState, newState) {
    try {
      await db.query(
        `INSERT INTO device_control_logs (user_id, relay_number, action, previous_state, new_state)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, relayNumber, action, previousState, newState]
      );
    } catch (error) {
      console.error('❌ Error logging device control:', error);
      // Don't throw - logging failure shouldn't break the main operation
    }
  }

  // ============ GET DEVICE CONTROL HISTORY ============
  static async getDeviceControlHistory(userId, limit = 50) {
    try {
      const result = await db.query(
        `SELECT relay_number, action, previous_state, new_state, timestamp
         FROM device_control_logs
         WHERE user_id = $1
         ORDER BY timestamp DESC
         LIMIT $2`,
        [userId, limit]
      );

      return result.rows;
    } catch (error) {
      console.error('❌ Error fetching device control history:', error);
      throw error;
    }
  }

  // ============ INITIALIZE ALL RELAYS FOR USER ============
  static async initializeAllRelays(userId) {
    try {
      // Initialize relay 1 and relay 2
      await this.initializeRelayStatus(userId, 1);
      await this.initializeRelayStatus(userId, 2);

      console.log(`✅ All relays initialized for user ${userId}`);
    } catch (error) {
      console.error('❌ Error initializing all relays:', error);
      throw error;
    }
  }

  // ============ VERIFY USER HAS DEVICE CONFIG ============
  static async userHasDeviceConfig(userId) {
    try {
      const result = await db.query(
        `SELECT COUNT(*) as count FROM device_configs WHERE user_id = $1`,
        [userId]
      );

      return result.rows[0].count > 0;
    } catch (error) {
      console.error('❌ Error checking device config:', error);
      return false;
    }
  }
}

module.exports = DeviceConfigService;
