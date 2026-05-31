import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import reviewRoutes from './routes/reviews.js';
import { initDatabase } from './config/database.js';
import { metricsMiddleware, metricsEndpoint } from './middleware/metrics.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3004;
const SERVICE_NAME = 'review-service';
const VERSION = '3.3';

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(metricsMiddleware);

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
app.use('/api/', limiter);

app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const user = req.user?.email || req.body?.email || 'anonymous';
    const status = res.statusCode;
    const emoji = status < 400 ? '✅' : '❌';
    
    console.log(`${emoji} [${SERVICE_NAME}] ${req.method} ${req.path}
   User: ${user}
   Status: ${status}
   Duration: ${duration}ms`);
  });
  
  next();
});

app.get('/api/reviews/metrics', metricsEndpoint);

app.get('/api/reviews/health', async (req, res) => {
  const health = {
    status: 'ok',
    service: SERVICE_NAME,
    version: VERSION,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'production',
    database: 'disconnected'
  };

  try {
    const { getConnection } = await import('./config/database.js');
    const connection = await getConnection();
    await connection.query('SELECT 1');
    connection.release();
    health.database = 'connected';
  } catch (error) {
    health.database = 'error';
    health.status = 'degraded';
  }

  res.status(health.status === 'ok' ? 200 : 503).json(health);
});

app.get('/api/reviews/ready', async (req, res) => {
  try {
    const { getConnection } = await import('./config/database.js');
    const connection = await getConnection();
    await connection.query('SELECT 1');
    connection.release();
    res.json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

app.get('/api/reviews/info', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: VERSION,
    description: 'Product reviews microservice',
    endpoints: [
      'GET  /api/reviews/health - Health check',
      'GET  /api/reviews/ready - Readiness probe',
      'GET  /api/reviews/metrics - Prometheus metrics',
      'GET  /api/reviews/info - Service information',
      'GET  /api/reviews/product/:id - Get product reviews',
      'POST /api/reviews - Create review'
    ],
    dependencies: {
      database: 'MariaDB'
    }
  });
});

app.use('/api/reviews', reviewRoutes);

app.use((req, res) => res.status(404).json({ error: 'Route non trouvée' }));

app.use((err, req, res, next) => {
  console.error(`[${SERVICE_NAME}] Error:`, err);
  res.status(500).json({ error: 'Erreur interne' });
});

const startServer = async () => {
  try {
    await initDatabase();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`
╔═══════════════════════════════════════════════
║   ⭐ ${SERVICE_NAME.toUpperCase()} - v${VERSION}
║
║   Port: ${PORT}
║   Environment: ${process.env.NODE_ENV || 'development'}
║   Database: ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || 3306}
║
║   📚 Endpoints:
║   GET  /api/reviews/health       - Health check
║   GET  /api/reviews/ready        - Ready check
║   GET  /api/reviews/metrics      - Prometheus
║   GET  /api/reviews/info         - Service info
║   GET  /api/reviews/product/:id  - Avis produit
║   POST /api/reviews              - Créer avis
║
╚═══════════════════════════════════════════════
      `);
    });
  } catch (error) {
    console.error(`❌ Failed to start ${SERVICE_NAME}:`, error);
    process.exit(1);
  }
};

startServer();