require "rate_limiter/version"

module RateLimiter
  class Middleware
    attr_reader :app, :store

    def initialize(app)
      @app = app
      @store = {}
    end

    def call(env)
      limit, reset_at = store[client_key(env)] || [nil, nil]

      if reset_at && reset_at < Time.now
        limit, reset_at = nil, nil
      end

      if limit.nil?
        limit = 60
        reset_at = Time.now + 3600
      end

      if limit > 0
        status, headers, body = app.call(env)
        limit -= 1
        headers["X-RateLimit-Limit"] = limit
        [status, headers, body]
      else
        [403, {}, ""]
      end
    ensure
      store[client_key(env)] = [limit, reset_at]
    end

    def client_key(env)
      Rack::Request.new(env).ip
    end
  end
end
