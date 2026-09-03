// ============================================================
// circuit-breaker.js — Circuit breaker pattern for external services
// ============================================================

export class CircuitBreaker {
  constructor(name, options = {}) {
    this.name = name;
    this.state = "CLOSED"; // CLOSED = normal, OPEN = blocked, HALF_OPEN = testing
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.threshold = options.threshold || 5;
    this.resetTimeout = options.resetTimeout || 60000; // 1 minute
    this.halfOpenMax = options.halfOpenMax || 3;
  }

  async execute(fn) {
    if (this.state === "OPEN") {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = "HALF_OPEN";
        this.successCount = 0;
      } else {
        throw new Error();
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    if (this.state === "HALF_OPEN") {
      this.successCount++;
      if (this.successCount >= this.halfOpenMax) {
        this.state = "CLOSED";
        this.successCount = 0;
      }
    }
  }

  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.threshold) {
      this.state = "OPEN";
    }
  }

  getState() {
    return { state: this.state, failureCount: this.failureCount, name: this.name };
  }

  reset() {
    this.state = "CLOSED";
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
  }
}

// Pre-configured breakers
export const supabaseBreaker = new CircuitBreaker("supabase", { threshold: 5, resetTimeout: 60000 });
export const upstashBreaker = new CircuitBreaker("upstash", { threshold: 3, resetTimeout: 30000 });
