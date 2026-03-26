import { Router } from 'express';

// We reuse the existing Stellar router logic from the dedicated stellar backend,
// but expose it under the unified `server/src/routes` structure.
const { stellarRouter } = require('../../../backend/server/src/routes/stellar') as {
  stellarRouter: Router;
};

export { stellarRouter };

