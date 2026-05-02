const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

// ── CORS ─────────────────────────────────────────
app.use((req, res, next) => {
  const allowedOrigins = [
    'https://pay.anathi.xyz',
    'http://localhost:5173',
    'http://localhost:4173',
  ];

  const origin = req.headers.origin;
  if (allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }

  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  next();
});

// ── DB ────────────────────────────────────────────
const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432,
  ssl: { rejectUnauthorized: false }
});

// ── Routes ────────────────────────────────────────
app.post("/pay", (req, res) => {
  const { amount, user } = req.body;
  const payment = {
    id: uuidv4(),
    amount,
    user,
    status: "SUCCESS",
    createdAt: new Date()
  };

  pool.query(
    "INSERT INTO payments (id, amount, user_name, status, created_at) VALUES ($1, $2, $3, $4, $5)",
    [payment.id, payment.amount, payment.user, payment.status, payment.createdAt],
    (err) => {
      if (err) {
        console.error("Error inserting payment:", err);
        return res.status(500).json({ error: "Internal server error" });
      }
      res.status(201).json(payment);
    }
  );
});

app.get("/payments", (req, res) => {
  pool.query("SELECT * FROM payments", (err, result) => {
    if (err) {
      console.error("Error fetching payments:", err);
      return res.status(500).json({ error: "Internal server error" });
    }
    res.json(result.rows);
  });
});

app.get("/health", (req, res) => {
  const now = new Date();
  res.send(`OK, Payment Service is healthy! Date: ${now.toLocaleDateString()}, Time: ${now.toLocaleTimeString()}`);
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});