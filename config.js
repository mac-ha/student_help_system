'use strict';

/**
 * Configuration.
 *
 * Values come from the environment first, then from a local `.env` file,
 * then from the defaults below. `.env` is git-ignored and never served.
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const ENV_FILE = path.join(__dirname, '.env');

function loadEnvFile(file) {
  if (!fs.existsSync(file)) return;
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile(ENV_FILE);

function buildDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const host = process.env.PGHOST || '127.0.0.1';
  const port = process.env.PGPORT || '5432';
  const user = process.env.PGUSER || 'postgres';
  const password = process.env.PGPASSWORD || '';
  const database = process.env.PGDATABASE || 'student_system';
  return `postgres://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${database}`;
}

const env = process.env.NODE_ENV || 'development';
const port = Number(process.env.PORT) || 2000;

let sessionSecret = process.env.SESSION_SECRET;
if (!sessionSecret) {
  if (env === 'production') {
    throw new Error('SESSION_SECRET must be set in production.');
  }
  // Never fall back to a shared, guessable secret. An ephemeral secret means
  // development sessions end when the process restarts, which is fine.
  sessionSecret = crypto.randomBytes(32).toString('hex');
  console.warn(
    '[config] SESSION_SECRET is not set; generated an ephemeral secret for this process.'
  );
}

const publicBaseUrl = (
  process.env.PUBLIC_BASE_URL || `http://127.0.0.1:${port}`
).replace(/\/+$/, '');

const mailTransport = String(process.env.MAIL_TRANSPORT || 'console').toLowerCase();
if (!['console', 'memory', 'smtp'].includes(mailTransport)) {
  throw new Error('MAIL_TRANSPORT must be one of: console, memory, smtp.');
}
if (mailTransport === 'memory' && env === 'production') {
  throw new Error('MAIL_TRANSPORT=memory is only available to the test suite.');
}

const mailFrom = process.env.MAIL_FROM || '';
if (mailTransport === 'smtp' && (!process.env.SMTP_HOST || !mailFrom)) {
  throw new Error('SMTP_HOST and MAIL_FROM must be set when MAIL_TRANSPORT=smtp.');
}

if (env === 'production' && mailTransport === 'console') {
  console.warn(
    '[mail] MAIL_TRANSPORT=console: password reset links will not be emailed. Configure SMTP.'
  );
}
if (env === 'production' && !publicBaseUrl.startsWith('https://')) {
  console.warn(
    '[mail] PUBLIC_BASE_URL is not HTTPS; reset links may expose tokens or be rejected by mail clients.'
  );
}

const passwordResetMinutes = Number(process.env.PASSWORD_RESET_MINUTES) || 30;
if (
  !Number.isInteger(passwordResetMinutes) ||
  passwordResetMinutes < 5 ||
  passwordResetMinutes > 120
) {
  throw new Error('PASSWORD_RESET_MINUTES must be an integer between 5 and 120.');
}

const config = {
  env,
  port,
  // Bind to loopback unless HOST is set explicitly.
  host: process.env.HOST || '127.0.0.1',
  trustProxy: /^(1|true|yes)$/i.test(process.env.TRUST_PROXY || ''),
  databaseUrl: buildDatabaseUrl(),
  sessionSecret,
  sessionLifetimeSeconds: 8 * 60 * 60,

  // Used to build absolute links inside emails.
  publicBaseUrl,
  passwordResetMinutes,

  mail: {
    transport: mailTransport,
    from: mailFrom || 'Student System <no-reply@localhost>',
    host: process.env.SMTP_HOST || '',
    port: Number(process.env.SMTP_PORT) || 587,
    secure: /^(1|true|yes)$/i.test(process.env.SMTP_SECURE || ''),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || ''
  },

  // Business rules taken from the flowchart.
  maxCoursesPerSemester: Number(process.env.MAX_COURSES) || 6,
  remarkFee: Number(process.env.REMARK_FEE) || 525
};

module.exports = config;
