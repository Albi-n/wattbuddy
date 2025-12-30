const express = require('express');
const cors = require('cors');

const app = express(); // ✅ app initialized FIRST

// ---------------- MIDDLEWARE ----------------
app.use(cors());
app.use(express.json()); // 🔴 REQUIRED
app.use(express.urlencoded({ extended: true }));

// ---------------- ROUTES ----------------
const authRoutes = require('./routes/authRoutes');
app.use('/api/auth', authRoutes);

// ---------------- TEST ROUTE ----------------
app.get('/', (req, res) => {
  res.send('WattBuddy Server Running');
});


app.post('/api/auth/test', (req, res) => {
  console.log('✅ TEST ROUTE HIT');
  res.json({ message: 'Auth route working' });
});


// ---------------- START SERVER ----------------
const PORT = 4000;
app.listen(4000, '0.0.0.0', () => {
  console.log('🚀 Server running on http://0.0.0.0:4000');
});

