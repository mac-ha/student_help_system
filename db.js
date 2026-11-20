'use strict';

const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30_000
});

pool.on('error', (err) => {
  console.error('Unexpected database error:', err.message);
});

module.exports = {
  pool,
  query: (text, params) => pool.query(text, params)
};
