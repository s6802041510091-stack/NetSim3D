import express, { type NextFunction, type Request, type Response } from 'express';
import { loadUser } from './auth.ts';
import { HttpError } from './errors.ts';
import { classRoutes, JoinLimiter } from './routes/classes.ts';
import { gameRoutes } from './routes/game.ts';
import { authRoutes, type AppOptions } from './routes/me.ts';

export type { AppOptions };

export function createApp(options: AppOptions, limiter = new JoinLimiter()) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));

  // Requests that change data must come from this site's own pages (blocks cross-site form posts).
  app.use((req: Request, _res: Response, next: NextFunction) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
    const origin = req.get('origin');
    if (origin) {
      let host = '';
      try {
        host = new URL(origin).host;
      } catch {
        // malformed Origin header
      }
      if (host !== req.get('host')) return next(new HttpError(403, 'bad_origin'));
    }
    next();
  });

  app.get('/api/health', async (_req, res) => {
    await options.pool.query('SELECT 1');
    res.json({ ok: true });
  });

  app.use('/api', loadUser(options.pool));
  app.use('/api', authRoutes(options));
  app.use('/api', classRoutes(options, limiter));
  app.use('/api', gameRoutes(options));

  app.use('/api', (_req, _res, next) => next(new HttpError(404, 'not_found')));

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof HttpError) {
      res.status(err.status).json({ error: err.code, ...(err.details ? { details: err.details } : {}) });
      return;
    }
    const e = err as { type?: string; status?: number };
    if (e?.type === 'entity.parse.failed') {
      res.status(400).json({ error: 'invalid_json' });
      return;
    }
    if (e?.type === 'entity.too.large') {
      res.status(413).json({ error: 'too_large' });
      return;
    }
    console.error(err);
    res.status(500).json({ error: 'server_error' });
  });

  return app;
}
