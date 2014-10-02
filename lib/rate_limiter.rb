require "rate_limiter/version"

module RateLimiter
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers["X-RateLimit-Limit"] = "60"
      [status, headers, body]
    end
  end
end
