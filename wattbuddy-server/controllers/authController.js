const pool = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');




// 🔐 REGISTER
exports.registerUser = async (req, res) => {
  console.log("📥 Register API hit");
  console.log("📦 Body received:", req.body);

  const { username, email, consumer_number, password } = req.body;

  try {
    // 1. Check if user already exists
    const userCheck = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR consumer_number = $2',
      [email, consumer_number]
    );

    if (userCheck.rows.length > 0) {
      return res.status(400).json({ message: 'User already exists' });
    }

    // 2. Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // 3. Insert user
    await pool.query(
      'INSERT INTO users (username, email, consumer_number, password) VALUES ($1, $2, $3, $4)',
      [username, email, consumer_number, hashedPassword]
    );

    console.log("✅ Registration successful");
    res.status(201).json({ message: 'Registration successful' });

  } catch (err) {
    console.error("❌ Registration error:", err);
    res.status(500).json({ message: 'Server error' });
  }
};






// 🔑 LOGIN (accept username OR email)
exports.loginUser = async (req, res) => {
  const { email, password } = req.body;

  console.log("📥 Login API hit with email/username:", email);
  console.log("📥 Incoming password:", password);

  if (!email || !password) {
    return res.status(400).json({ message: 'Email/username and password required' });
  }

  try {
    console.log("⏱️ Starting database query...");
    
    // Query by email OR username with timeout
    const result = await Promise.race([
      pool.query(
        'SELECT * FROM users WHERE email=$1 OR username=$1',
        [email]
      ),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Database query timeout')), 5000)
      )
    ]);

    console.log("🔍 User search result:", result.rows.length > 0 ? "User found" : "No user found");

    if (result.rows.length === 0) {
      console.log("❌ User not found for email/username:", email);
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    console.log("🔐 Comparing password for user:", user.username);
    console.log("🔐 Stored password (first 30 chars):", user.password.substring(0, 30));
    console.log("🔐 Incoming password (first 30 chars):", password.substring(0, 30));
    console.log("🔐 Stored password length:", user.password.length);
    console.log("🔐 Incoming password length:", password.length);

    // Check if stored password is bcrypt hash (starts with $2a$, $2b$, $2y$, or $2x$)
    const isBcryptHash = /^\$2[aby]\$/.test(user.password);
    console.log("🔐 Is bcrypt hash:", isBcryptHash);

    let isMatch = false;
    
    if (isBcryptHash) {
      // Password is hashed, use bcrypt.compare
      isMatch = await bcrypt.compare(password, user.password);
      console.log("🔐 Bcrypt comparison result:", isMatch);
    } else {
      // Password is plain text (legacy), direct comparison
      isMatch = password === user.password;
      console.log("🔐 Plain text comparison result:", isMatch);
      console.log("⚠️  WARNING: Plain text password detected! User should be migrated to bcrypt.");
    }
    
    if (!isMatch) {
      console.log("❌ Password mismatch for user:", email);
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      'secretkey',
      { expiresIn: '1h' }
    );

    console.log("✅ Login successful for user:", user.username);
    res.json({
      message: 'Login successful',
      token,
      user: {
        username: user.username,
        email: user.email,
        consumer_number: user.consumer_number
      }
    });

  } catch (err) {
    console.error("❌ Login error:", err);
    res.status(500).json({ message: 'Server error' });
  }
};
