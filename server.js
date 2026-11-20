'use strict';

const app = require('./app');
const config = require('./config');
const { pool } = require('./db');

async function start() {
  await pool.query('SELECT 1');

  const server = app.listen(config.port, config.host, () => {
    const shown = config.host === '0.0.0.0' || config.host === '::' ? '127.0.0.1' : config.host;
    console.log(`Student system running at http://${shown}:${config.port}`);
  });

  const shutdown = async (signal) => {
    console.log(`\n${signal} received, shutting down...`);
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  return server;
}

if (require.main === module) {
  start().catch((err) => {
    console.error('Unable to start the server:', err.message);
    if (/ECONNREFUSED|password|database/i.test(err.message)) {
      console.error('Check DATABASE_URL in .env — see .env.example.');
    }
    process.exit(1);
  });
}

module.exports = { start };
