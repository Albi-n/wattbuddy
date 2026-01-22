const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIO = require('socket.io');
const moment = require('moment');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, { cors: { origin: "*" } });

// ============ MIDDLEWARE ============
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ============ SERVICES ============
const ESP32StorageService = require('./services/esp32StorageService');
const RealtimeGraphService = require('./services/realtimeGraphService');
const MLPredictionService = require('./services/mlPredictionService');
const PowerLimitService = require('./services/powerLimitService');
const MonthlyUsageService = require('./services/monthlyUsageService');
const DeviceConfigService = require('./services/deviceConfigService');
const AnomalyDetectionService = require('./services/anomalyDetectionService');

// ============ ROUTES ============
const authRoutes = require('./routes/authRoutes');
const mlRoutes = require('./routes/mlRoutes');
const usageRoutes = require('./routes/usageRoutes');
const predictionRoutes = require('./routes/predictionRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const deviceRoutes = require('./routes/deviceRoutes');

app.use('/api/auth', authRoutes);
app.use('/api/ml', mlRoutes);
app.use('/api/usage', usageRoutes);
app.use('/api/predictions', predictionRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/devices', deviceRoutes);

// ============ TEST ROUTE ============
app.get('/', (req, res) => {
  res.send('🚀 WattBuddy Server Running with All 4 Features!');
});

// ============ 1️⃣ POWER-LIMIT NOTIFICATION ENDPOINTS ============
app.post('/api/power-limit/check', async (req, res) => {
  try {
    const { userId, currentUsage, dailyLimit } = req.body;
    const notification = await PowerLimitService.checkPowerLimit(userId, currentUsage, dailyLimit);
    res.json({ success: true, ...notification });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/power-limit/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const settings = await PowerLimitService.getPowerLimitSettings(userId);
    res.json({ success: true, ...settings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/power-limit/set', async (req, res) => {
  try {
    const { userId, dailyLimit } = req.body;
    const result = await PowerLimitService.setPowerLimit(userId, dailyLimit);
    res.json({ success: true, limit: result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ 2️⃣ ESP32 DATA STORAGE ENDPOINTS ============
app.post('/api/esp32/data', async (req, res) => {
  try {
    const userId = req.body.userId || req.headers['x-user-id'];
    
    if (!userId) {
      return res.status(400).json({ 
        success: false,
        error: 'User ID is required (in body or x-user-id header)' 
      });
    }

    const { voltage, current, power, energy, pf, frequency, temperature, timestamp } = req.body;
    
    const reading = {
      power,
      voltage,
      current,
      energy,
      pf,
      frequency,
      temperature,
      timestamp: timestamp || new Date()
    };

    const stored = await ESP32StorageService.storeReading(userId, reading);
    
    // Broadcast only to the specific user's room
    io.to(`user_${userId}`).emit('live_data_update', {
      id: stored.id,
      voltage: stored.voltage,
      current: stored.current,
      power: stored.power_consumption,
      energy: stored.energy,
      pf: stored.power_factor,
      temperature: stored.temperature,
      timestamp: stored.recorded_at
    });
    
    console.log(`📊 ESP32 Data received for user ${userId}: V=${voltage}V, I=${current}A, P=${power}W`);
    res.json({ success: true, stored });
  } catch (error) {
    console.error('❌ Error storing ESP32 data:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get latest readings for specific user
app.get('/api/esp32/readings/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = req.query.limit || 100;

    const readings = await ESP32StorageService.getLatestReadings(userId, parseInt(limit));

    res.json({ 
      success: true,
      count: readings.length,
      readings 
    });
  } catch (error) {
    console.error('❌ Error fetching readings:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get latest single reading for specific user
app.get('/api/esp32/latest/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const reading = await ESP32StorageService.getLatestReading(userId);

    if (!reading) {
      return res.json({ success: true, reading: null, message: 'No readings found' });
    }

    res.json({ 
      success: true,
      reading: {
        id: reading.id,
        voltage: reading.voltage,
        current: reading.current,
        power: reading.power_consumption,
        energy: reading.energy,
        pf: reading.power_factor,
        temperature: reading.temperature,
        timestamp: reading.recorded_at
      }
    });
  } catch (error) {
    console.error('❌ Error fetching latest reading:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============ ESP32 LIVE DATA PROXY ============
// Fetch live readings from ESP32 through backend
const axios = require('axios');
const esp32URL = 'http://wattbuddy.local/api/readings'; // Use mDNS hostname (works if ESP32 is running)

app.get('/api/esp32/live', async (req, res) => {
  try {
    // Fetch data from ESP32
    const response = await axios.get(esp32URL, { timeout: 5000 });
    const data = response.data;
    
    console.log(`✅ Live ESP32 Data: V=${data.voltage}V, P=${data.power}W, I=${data.current}A`);
    
    res.json({
      success: true,
      voltage: parseFloat(data.voltage) || 0,
      current: parseFloat(data.current) || 0,
      power: parseFloat(data.power) || 0,
      energy: parseFloat(data.energy) || 0,
      bill: parseFloat(data.bill) || 0,
      relay1: data.relay1 || false,
      relay2: data.relay2 || false,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('❌ ESP32 Fetch Error:', error.code || error.message);
    console.error('   Trying to reach:', esp32URL);
    res.status(503).json({
      error: 'Unable to reach ESP32',
      message: error.message,
      hint: 'Make sure ESP32 is powered on and running the firmware. Reachable at http://wattbuddy.local/api/readings'
    });
  }
});

// ============ RELAY CONTROL PROXY ============
app.post('/api/esp32/relay/:relay/:action', async (req, res) => {
  try {
    const { relay, action } = req.params;
    const relayNum = relay === 'relay1' ? '1' : '2';
    const cmd = action === 'on' ? 'on' : 'off';
    
    const relayURL = `http://${esp32IP}/api/relay${relayNum}/${cmd}`;
    const response = await axios.get(relayURL, { timeout: 3000 });
    
    console.log(`🔌 Relay ${relayNum} turned ${cmd}`);
    res.json({ success: true, relay, action, data: response.data });
  } catch (error) {
    console.error('❌ Relay Control Error:', error.message);
    res.status(503).json({ error: 'Unable to control relay', message: error.message });
  }
});

// ============ ANOMALY DETECTION ENDPOINT ============
app.post('/api/anomaly/check', async (req, res) => {
  try {
    const userId = req.body.userId || req.headers['x-user-id'];
    const { voltage, current, power } = req.body;

    if (!userId || power === undefined) {
      return res.status(400).json({ error: 'userId and power are required' });
    }

    const result = await AnomalyDetectionService.checkAnomalies(userId, voltage || 220, current || 0, power);
    
    if (result.hasAnomalies) {
      console.log(`🚨 Anomalies detected for user ${userId}:`, result.anomalies);
    }

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('❌ Anomaly Detection Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============ LIVE CHART ENDPOINTS (NEW) ============
// In-memory storage for latest readings (last 60 per user)
const latestReadings = new Map();
const MAX_READINGS = 60;

app.post('/api/esp32/reading', (req, res) => {
  try {
    const { userId, voltage, current, power, energy_kWh, cost_INR, timestamp } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId required' });
    }

    const reading = {
      voltage: parseFloat(voltage) || 0,
      current: parseFloat(current) || 0,
      power: parseFloat(power) || 0,
      energy_kWh: parseFloat(energy_kWh) || 0,
      cost_INR: parseFloat(cost_INR) || 0,
      timestamp: timestamp || Date.now()
    };

    // Store in memory (max 60 readings per user)
    if (!latestReadings.has(userId)) {
      latestReadings.set(userId, []);
    }
    
    const userReadings = latestReadings.get(userId);
    userReadings.push(reading);
    if (userReadings.length > MAX_READINGS) {
      userReadings.shift();
    }

    // Log to console
    console.log(`⚡ [${new Date().toLocaleTimeString()}] V: ${reading.voltage.toFixed(1)}V | I: ${reading.current.toFixed(3)}A | P: ${reading.power.toFixed(1)}W | E: ${reading.energy_kWh.toFixed(4)}kWh`);

    // Broadcast to connected clients
    io.to(`user_${userId}`).emit('power_reading', reading);

    res.json({ success: true, reading });
  } catch (error) {
    console.error('❌ Error storing reading:', error.message);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/esp32/latest/:userId', (req, res) => {
  try {
    const { userId } = req.params;
    const readings = latestReadings.get(userId) || [];
    
    if (readings.length === 0) {
      return res.json({
        voltage: 0,
        current: 0,
        power: 0,
        energy_kWh: 0,
        cost_INR: 0,
        timestamp: Date.now()
      });
    }

    const latest = readings[readings.length - 1];
    res.json(latest);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/esp32/history/:userId', (req, res) => {
  try {
    const { userId } = req.params;
    const readings = latestReadings.get(userId) || [];
    
    res.json({
      data: readings,
      count: readings.length,
      maxReadings: MAX_READINGS
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/esp32/latest/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 100 } = req.query;
    const readings = await ESP32StorageService.getLatestReadings(userId, limit);
    res.json({ success: true, readings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/esp32/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { date = moment().format('YYYY-MM-DD') } = req.query;
    const stats = await ESP32StorageService.getDailySummary(userId, date);
    res.json({ success: true, stats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/esp32/hourly/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { date = moment().format('YYYY-MM-DD') } = req.query;
    const hourly = await ESP32StorageService.getHourlyStats(userId, date);
    res.json({ success: true, hourly });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ 3️⃣ LIVE REAL-TIME GRAPH ENDPOINTS ============
app.get('/api/graph/live/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { minutes = 60 } = req.query;
    const data = await RealtimeGraphService.getLiveGraphData(userId, minutes);
    res.json({ success: true, graphData: data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/graph/comparison/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const comparison = await RealtimeGraphService.getComparisonData(userId);
    res.json({ success: true, ...comparison });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ 4️⃣ ML PREDICTION ENDPOINTS ============
app.get('/api/ml-predict/next-hour/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const prediction = await MLPredictionService.predictNextHour(userId);
    res.json({ success: true, prediction });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ml-predict/next-day/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const prediction = await MLPredictionService.predictNextDay(userId);
    res.json({ success: true, prediction });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ml-predict/anomalies/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const anomalies = await MLPredictionService.detectAnomalies(userId);
    res.json({ success: true, ...anomalies });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ml-predict/recommendations/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const recommendations = await MLPredictionService.getRecommendations(userId);
    res.json({ success: true, ...recommendations });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ WEBSOCKET (Socket.io) FOR REAL-TIME UPDATES ============
io.on('connection', (socket) => {
  console.log(`✅ New WebSocket connection: ${socket.id}`);

  // User login event - join user to their specific room
  socket.on('user_login', (data) => {
    const { userId, username } = data;
    if (!userId) {
      console.warn('⚠️ User login without userId');
      return;
    }
    
    socket.join(`user_${userId}`);
    socket.join(`user_notifications_${userId}`);
    console.log(`📡 User ${userId} (${username}) joined real-time channels`);
    
    // Notify user of successful connection
    socket.emit('user_connected', {
      userId,
      timestamp: new Date().toISOString()
    });
  });

  // Join user to their room for real-time updates (legacy support)
  socket.on('join_user', (userId) => {
    if (!userId) {
      console.warn('⚠️ Join user without userId');
      return;
    }
    
    socket.join(`user_${userId}`);
    console.log(`📡 User ${userId} joined real-time channel`);
  });

  // Relay control event
  socket.on('relay_control', async (data) => {
    const { userId, relayNumber, action } = data;
    console.log(`🔌 Relay control event: User ${userId}, Relay ${relayNumber}, Action ${action}`);
    
    try {
      const updated = await DeviceConfigService.setRelayState(userId, relayNumber, action === 'on');
      io.to(`user_${userId}`).emit('relay_status_updated', {
        relayNumber,
        isOn: updated.is_on,
        timestamp: updated.last_toggled_at
      });
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Broadcast live data when ESP32 sends data
  socket.on('esp32_data', async (data) => {
    const { userId, ...reading } = data;
    io.to(`user_${userId}`).emit('live_data_update', {
      timestamp: new Date().toISOString(),
      ...reading
    });
  });

  // Get live graph data on demand
  socket.on('request_graph_data', async (userId) => {
    try {
      const data = await RealtimeGraphService.getLiveGraphData(userId);
      io.to(`user_${userId}`).emit('graph_data', data);
    } catch (error) {
      console.error('❌ Error fetching graph data:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 WebSocket disconnected: ${socket.id}`);
  });
});

// ============ RELAY CONTROL ENDPOINTS ============
// In-memory relay states (replace with database in production)
const relayStates = {
  relay1: false,
  relay2: false,
  voltage: 230,
  current: 0,
  power: 0,
  anomaly: false,
};

// Relay 1 Control
app.post('/api/relay1/on', (req, res) => {
  console.log('🔌 Relay 1: Turning ON');
  relayStates.relay1 = true;
  res.json({ 
    success: true, 
    message: 'Relay 1 turned ON',
    state: relayStates.relay1 
  });
});

app.post('/api/relay1/off', (req, res) => {
  console.log('🔌 Relay 1: Turning OFF');
  relayStates.relay1 = false;
  res.json({ 
    success: true, 
    message: 'Relay 1 turned OFF',
    state: relayStates.relay1 
  });
});

// Relay 2 Control
app.post('/api/relay2/on', (req, res) => {
  console.log('🔌 Relay 2: Turning ON');
  relayStates.relay2 = true;
  res.json({ 
    success: true, 
    message: 'Relay 2 turned ON',
    state: relayStates.relay2 
  });
});

app.post('/api/relay2/off', (req, res) => {
  console.log('🔌 Relay 2: Turning OFF');
  relayStates.relay2 = false;
  res.json({ 
    success: true, 
    message: 'Relay 2 turned OFF',
    state: relayStates.relay2 
  });
});

// Get Relay Status
app.get('/api/relay/status', (req, res) => {
  console.log('📊 Fetching relay status');
  res.json({
    success: true,
    relay1: relayStates.relay1,
    relay2: relayStates.relay2,
    voltage: relayStates.voltage,
    current: relayStates.current,
    power: relayStates.power,
    anomaly: relayStates.anomaly,
  });
});

// Get ESP32 Latest Data
app.get('/api/esp32/latest', (req, res) => {
  console.log('📡 Fetching latest ESP32 data');
  res.json({
    success: true,
    voltage: 230 + (Math.random() * 10 - 5),
    current: relayStates.relay1 ? 5 + Math.random() : 0.5 + Math.random(),
    power: relayStates.relay1 ? 1150 + Math.random() * 100 : 115 + Math.random() * 50,
    energy: 125.5 + (relayStates.relay1 ? 0.5 : 0),
    timestamp: new Date(),
  });
});

// ============ START SERVER ============
const PORT = process.env.PORT || 4000;
server.listen(PORT, '0.0.0.0', () => {
  console.log('\n🚀 ================================');
  console.log('   WattBuddy Server Running');
  console.log('================================');
  console.log(`🌐 http://0.0.0.0:${PORT}`);
  console.log('\n✨ Features Enabled:');
  console.log('1️⃣  Power-Limit Notifications');
  console.log('2️⃣  ESP32 Data Storage (PostgreSQL)');
  console.log('3️⃣  Live Real-Time Graph (WebSocket)');
  console.log('4️⃣  ML Predictions & Anomaly Detection');
  console.log('================================\n');
});

module.exports = { app, server, io };

