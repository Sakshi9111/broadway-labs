-- This runs automatically the first time the Postgres container initializes its data directory.
-- The Flask app also creates this table itself, so this file is optional/belt-and-suspenders.

CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);