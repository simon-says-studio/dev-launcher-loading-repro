// Reproduction helper: hold every manifest and bundle response for
// REPRO_DELAY_MS, so a slow dev server (a tunnel, a large project, a cold
// cache, a fingerprint runtime version) is deterministic on any machine.
const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
const delayMs = Number(process.env.REPRO_DELAY_MS || 0);

if (delayMs > 0) {
  config.server = {
    ...config.server,
    enhanceMiddleware: (middleware) => (req, res, next) => {
      const path = (req.url || '').split('?')[0];
      const slow = path === '/' || path.endsWith('.bundle');
      if (!slow) return middleware(req, res, next);
      console.log(`[repro] holding ${req.method} ${path} for ${delayMs}ms`);
      setTimeout(() => middleware(req, res, next), delayMs);
    },
  };
}

module.exports = config;
