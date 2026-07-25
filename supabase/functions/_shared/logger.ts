/**
 * Shared structured logging utility for Supabase Edge Functions
 * Provides consistent JSON logging with request tracing across all functions
 *
 * Usage:
 *   const logger = createLogger('function-name');
 *   const traceId = logger.info('Starting operation', { userId: '123' }, incomingTraceId);
 *   // Include traceId in response headers for client correlation
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogContext {
  level: LogLevel;
  functionName: string;
  requestId: string;
  userId?: string;
  timestamp: string;
  message: string;
  data?: Record<string, unknown>;
  error?: {
    message: string;
    stack?: string;
    code?: string;
  };
}

/**
 * Generate or validate a request ID
 * Accepts an incoming ID for trace correlation, generates UUID if not provided
 */
function generateRequestId(incomingHeader?: string): string {
  if (incomingHeader && incomingHeader.trim()) {
    return incomingHeader.trim();
  }
  // Generate a UUID-like ID (Deno doesn't have native crypto.randomUUID in all versions)
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Create a logger instance for a specific Edge Function
 * Returns methods to log at different levels with automatic trace ID propagation
 */
export function createLogger(functionName: string) {
  return {
    /**
     * Log at a specific level
     * Returns the trace ID for inclusion in response headers
     */
    log: (level: LogLevel, message: string, data?: any, requestId?: string): string => {
      const traceId = generateRequestId(requestId);
      const logEntry: LogContext = {
        level,
        functionName,
        requestId: traceId,
        timestamp: new Date().toISOString(),
        message,
        data,
      };
      console.log(JSON.stringify(logEntry));
      return traceId;
    },

    /**
     * Log at debug level (lowest priority)
     */
    debug: (message: string, data?: any, requestId?: string): string => {
      const traceId = generateRequestId(requestId);
      const logEntry: LogContext = {
        level: 'debug',
        functionName,
        requestId: traceId,
        timestamp: new Date().toISOString(),
        message,
        data,
      };
      console.debug(JSON.stringify(logEntry));
      return traceId;
    },

    /**
     * Log at info level (normal operations)
     */
    info: (message: string, data?: any, requestId?: string): string => {
      const traceId = generateRequestId(requestId);
      const logEntry: LogContext = {
        level: 'info',
        functionName,
        requestId: traceId,
        timestamp: new Date().toISOString(),
        message,
        data,
      };
      console.log(JSON.stringify(logEntry));
      return traceId;
    },

    /**
     * Log at warn level (recoverable issues)
     */
    warn: (message: string, data?: any, requestId?: string): string => {
      const traceId = generateRequestId(requestId);
      const logEntry: LogContext = {
        level: 'warn',
        functionName,
        requestId: traceId,
        timestamp: new Date().toISOString(),
        message,
        data,
      };
      console.warn(JSON.stringify(logEntry));
      return traceId;
    },

    /**
     * Log at error level (unrecoverable issues)
     */
    error: (message: string, error?: Error | string, data?: any, requestId?: string): string => {
      const traceId = generateRequestId(requestId);

      let errorContext: LogContext['error'] | undefined;
      if (error) {
        if (error instanceof Error) {
          errorContext = {
            message: error.message,
            stack: error.stack,
            code: (error as any).code,
          };
        } else {
          errorContext = { message: String(error) };
        }
      }

      const logEntry: LogContext = {
        level: 'error',
        functionName,
        requestId: traceId,
        timestamp: new Date().toISOString(),
        message,
        data,
        error: errorContext,
      };
      console.error(JSON.stringify(logEntry));
      return traceId;
    },
  };
}

/**
 * Extract trace ID from incoming request headers
 * Looks for: X-Trace-ID, X-Request-ID, or X-Correlation-ID
 */
export function extractTraceId(headers: Record<string, string>): string | undefined {
  return (
    headers['x-trace-id'] ||
    headers['x-request-id'] ||
    headers['x-correlation-id'] ||
    headers['traceparent']?.split('-')[1] // OpenTelemetry format
  );
}

/**
 * Add trace ID to response headers for client-side correlation
 */
export function addTraceIdToResponse(
  headers: Record<string, string>,
  traceId: string
): Record<string, string> {
  return {
    ...headers,
    'X-Trace-ID': traceId,
    'X-Request-ID': traceId,
  };
}
