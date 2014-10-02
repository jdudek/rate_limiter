require "rate_limiter/version"

module RateLimiter
  class Middleware
    def initialize(app)
      @app = app
      @limit = 60
    end

    def call(env)
      status, headers, body = @app.call(env)
      @limit -= 1
      headers["X-RateLimit-Limit"] = @limit
      [status, headers, body]
    end
  end
end
