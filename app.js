const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

let payments = [];

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

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
      console.error("Error inserting payment into database:", err);
      res.status(500).json({ error: "Internal server error" });
      return;
    }

    res.status(201).json(payment);
  });
});

app.get("/payments", (req, res) => {
  pool.query("SELECT * FROM payments", (err, result) => {
    if (err) {
      console.error("Error fetching payments from database:", err);
      res.status(500).json({ error: "Internal server error" });
      return;
    }

    res.json(result.rows);
  });
});

app.get("/health", (req, res) => {
  res.send("OK");
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});