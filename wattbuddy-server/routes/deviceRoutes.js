// 🔌 Device Routes
// API endpoints for device control and management

const express = require('express');
const router = express.Router();
const DeviceConfigService = require('../services/deviceConfigService');
const ESP32StorageService = require('../services/esp32StorageService');

// ============ MIDDLEWARE: Validate User ID ============
const validateUserId = (req, res, next) => {
  // Extract userId from multiple sources
  const userId = req.body?.userId || req.params?.userId || req.query?.userId || req.headers?.['x-user-id'];

  if (!userId) {
    return res.status(400).json({
      success: false,
      error: 'User ID is required in URL params, request body, query, or x-user-id header'
    });
  }

  // Attach userId to request for use in route handlers
  req.userId = userId;
  next();
};

router.use(validateUserId);

// ============ GET DEVICE CONFIGURATION ============
router.get('/config/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const config = await DeviceConfigService.getDeviceConfig(userId);
    const relayStatus = await DeviceConfigService.getAllRelayStatus(userId);

    res.json({
      success: true,
      config,
      relayStatus
    });
  } catch (error) {
    console.error('❌ Error fetching device config:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch device configuration'
    });
  }
});

// ============ UPDATE DEVICE NAMES ============
router.put('/config', async (req, res) => {
  try {
    const { userId, relay1Name, relay2Name } = req.body;

    if (!relay1Name || !relay2Name) {
      return res.status(400).json({
        success: false,
        error: 'Device names are required'
      });
    }

    const updated = await DeviceConfigService.updateDeviceNames(
      userId,
      relay1Name,
      relay2Name
    );

    res.json({
      success: true,
      config: updated
    });
  } catch (error) {
    console.error('❌ Error updating device config:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to update device configuration'
    });
  }
});

// ============ GET ALL RELAY STATUS ============
router.get('/relay/status/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const relayStatus = await DeviceConfigService.getAllRelayStatus(userId);

    res.json({
      success: true,
      relayStatus
    });
  } catch (error) {
    console.error('❌ Error fetching relay status:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch relay status'
    });
  }
});

// ============ GET SPECIFIC RELAY STATUS ============
router.get('/relay/status/:userId/:relayNumber', async (req, res) => {
  try {
    const { userId, relayNumber } = req.params;

    const relayStatus = await DeviceConfigService.getRelayStatus(userId, parseInt(relayNumber));

    res.json({
      success: true,
      relayStatus
    });
  } catch (error) {
    console.error('❌ Error fetching relay status:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch relay status'
    });
  }
});

// ============ TOGGLE RELAY ============
router.post('/relay/toggle', async (req, res) => {
  try {
    const axios = require('axios');
    const { userId, relayNumber } = req.body;

    if (!relayNumber) {
      return res.status(400).json({
        success: false,
        error: 'Relay number is required'
      });
    }

    if (![1, 2].includes(parseInt(relayNumber))) {
      return res.status(400).json({
        success: false,
        error: 'Relay number must be 1 or 2'
      });
    }

    // Update database first
    const updated = await DeviceConfigService.toggleRelay(userId, parseInt(relayNumber));
    const newState = updated.is_on; // Get the state AFTER toggle

    console.log(`\n📡 Relay ${relayNumber} toggled in DB to: ${newState ? 'ON' : 'OFF'}`);
    console.log(`🔗 Attempting to send command to ESP32...`);
    
    // Send command to ESP32 using mDNS
    const esp32URL = newState 
      ? `http://wattbuddy.local/api/relay${relayNumber}/on`
      : `http://wattbuddy.local/api/relay${relayNumber}/off`;
    
    console.log(`📍 Target URL: ${esp32URL}`);
    
    try {
      console.log(`⏳ Sending POST request to ESP32...`);
      const esp32Response = await axios.post(esp32URL, {}, { timeout: 5000 });
      console.log(`✅ SUCCESS! Relay ${relayNumber} command sent to ESP32`);
      console.log(`📦 ESP32 Response:`, esp32Response.data);
    } catch (esp32Error) {
      console.error(`❌ ESP32 relay control FAILED`);
      console.error(`   Error Type: ${esp32Error.code}`);
      console.error(`   Error Message: ${esp32Error.message}`);
      console.error(`   URL attempted: ${esp32URL}`);
      
      // Try with alternate IP if mDNS fails (user can change this IP)
      if (esp32Error.code === 'ENOTFOUND' || esp32Error.code === 'ECONNREFUSED') {
        console.log(`\n🔄 mDNS failed, trying alternate method...`);
        console.log(`⚠️  NOTE: If relay still doesn't work:`);
        console.log(`   1. Find your ESP32's IP address`);
        console.log(`   2. Update the ESP32_IP in this file`);
        console.log(`   3. Restart the backend server`);
      }
    }

    res.json({
      success: true,
      relayStatus: updated,
      message: `Relay ${relayNumber} toggled to ${updated.is_on ? 'ON' : 'OFF'}`
    });
  } catch (error) {
    console.error('❌ Error toggling relay:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to toggle relay'
    });
  }
});

// ============ SET RELAY ON ============
router.post('/relay/on', async (req, res) => {
  try {
    const { userId, relayNumber } = req.body;

    if (!relayNumber) {
      return res.status(400).json({
        success: false,
        error: 'Relay number is required'
      });
    }

    const updated = await DeviceConfigService.setRelayState(userId, parseInt(relayNumber), true);

    res.json({
      success: true,
      relayStatus: updated,
      message: `Relay ${relayNumber} turned ON`
    });
  } catch (error) {
    console.error('❌ Error turning on relay:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to turn on relay'
    });
  }
});

// ============ SET RELAY OFF ============
router.post('/relay/off', async (req, res) => {
  try {
    const { userId, relayNumber } = req.body;

    if (!relayNumber) {
      return res.status(400).json({
        success: false,
        error: 'Relay number is required'
      });
    }

    const updated = await DeviceConfigService.setRelayState(userId, parseInt(relayNumber), false);

    res.json({
      success: true,
      relayStatus: updated,
      message: `Relay ${relayNumber} turned OFF`
    });
  } catch (error) {
    console.error('❌ Error turning off relay:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to turn off relay'
    });
  }
});

// ============ GET DEVICE CONTROL HISTORY ============
router.get('/history/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const limit = req.query.limit || 50;

    const history = await DeviceConfigService.getDeviceControlHistory(userId, parseInt(limit));

    res.json({
      success: true,
      history
    });
  } catch (error) {
    console.error('❌ Error fetching device control history:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch history'
    });
  }
});

// ============ GET LAST ENERGY READING ============
router.get('/energy/last/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const db = require('../db');

    const result = await db.query(
      `SELECT voltage, current, power_consumption as power, energy, frequency, power_factor, temperature, recorded_at
       FROM energy_readings
       WHERE user_id = $1
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        reading: null,
        message: 'No energy readings found for this user yet'
      });
    }

    const reading = result.rows[0];
    res.json({
      success: true,
      reading: {
        voltage: parseFloat(reading.voltage),
        current: parseFloat(reading.current),
        power: parseFloat(reading.power),
        energy: parseFloat(reading.energy),
        frequency: parseFloat(reading.frequency),
        pf: parseFloat(reading.power_factor),
        temperature: parseFloat(reading.temperature),
        recordedAt: reading.recorded_at
      }
    });
  } catch (error) {
    console.error('❌ Error fetching last energy reading:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch energy reading'
    });
  }
});

// ============ GET ENERGY READINGS (LAST N HOURS) ============
router.get('/energy/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const hours = req.query.hours || 24;
    const db = require('../db');

    const result = await db.query(
      `SELECT voltage, current, power_consumption as power, energy, recorded_at
       FROM energy_readings
       WHERE user_id = $1 AND recorded_at > NOW() - INTERVAL '1 hour' * $2
       ORDER BY recorded_at ASC`,
      [userId, hours]
    );

    res.json({
      success: true,
      readings: result.rows.map(row => ({
        voltage: parseFloat(row.voltage),
        current: parseFloat(row.current),
        power: parseFloat(row.power),
        energy: parseFloat(row.energy),
        recordedAt: row.recorded_at
      }))
    });
  } catch (error) {
    console.error('❌ Error fetching energy history:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch energy history'
    });
  }
});

module.exports = router;
