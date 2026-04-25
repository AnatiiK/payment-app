CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY,
  amount INT,
  user_name TEXT,
  status TEXT,
  created_at TIMESTAMP
);