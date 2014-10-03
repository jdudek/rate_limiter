require "rate_limiter/version"

module RateLimiter
  class Middleware
    DEFAULT_BLOCK = lambda { |env| Rack::Request.new(env).ip }

    attr_reader :app, :store

    def initialize(app, options = {}, &block)
      @app = app
      @options = options
      @block = block || DEFAULT_BLOCK
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
        [429, {}, ""]
      end
    ensure
      store[client_key(env)] = [limit, reset_at]
    end

    def client_key(env)
      @block.call(env)
    end
  end
end
