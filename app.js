'use strict';

const path = require('path');
const express = require('express');
const helmet = require('helmet');
const config = require('./config');
const { apiLimiter } = require('./middleware/rate-limit');

const authRoutes = require('./routes/auth');
const referenceRoutes = require('./routes/reference');
const studentRoutes = require('./routes/student');
const hodRoutes = require('./routes/hod');
const adminRoutes = require('./routes/admin');

const app = express();

app.disable('x-powered-by');
if (config.trustProxy) app.set('trust proxy', 1);

// Security headers. All scripts and styles are local, so the policy can stay
// strict; `upgradeInsecureRequests` is disabled so local HTTP development works.
app.use(
  helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'"],
        imgSrc: ["'self'", 'data:'],
        fontSrc: ["'self'"],
        connectSrc: ["'self'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        frameAncestors: ["'none'"],
        formAction: ["'self'"],
        upgradeInsecureRequests: null
      }
    }
  })
);

app.use(express.json({ limit: '100kb' }));

// Only the public folder is exposed; source files, .env and node_modules stay private.
app.use(
  express.static(path.join(__dirname, 'public'), {
    etag: true,
    setHeaders(res, filePath) {
      if (filePath.endsWith('.html')) {
        res.setHeader('Cache-Control', 'no-cache');
      } else if (config.env === 'production') {
        res.setHeader('Cache-Control', 'public, max-age=3600');
      } else {
        res.setHeader('Cache-Control', 'no-cache');
      }
    }
  })
);

app.use('/api', apiLimiter);
app.use('/api/auth', authRoutes);
app.use('/api/reference', referenceRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/hod', hodRoutes);
app.use('/api/admin', adminRoutes);

app.get('/api/health', async (req, res) => {
  try {
    const { query } = require('./db');
    await query('SELECT 1');
    res.json({ status: 'ok' });
  } catch {
    res.status(503).json({ status: 'database unavailable' });
  }
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ error: 'Not found.' });
  }
  return res.status(404).sendFile(path.join(__dirname, 'public', 'index.html'));
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  const status = err.status && err.status >= 400 && err.status < 600 ? err.status : 500;

  // Client mistakes are not server incidents; only log real failures.
  if (status >= 500) console.error(err.stack || err);

  if (res.headersSent) return next(err);

  let message = err.message;
  if (status >= 500) {
    message = 'Something went wrong on the server.';
  } else if (err.type === 'entity.parse.failed') {
    message = 'Request body must be valid JSON.';
  }

  return res.status(status).json({ error: message });
});

module.exports = app;
