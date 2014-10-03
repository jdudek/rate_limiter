require "rate_limiter/version"

module RateLimiter
  class Middleware
    DEFAULT_BLOCK = lambda { |env| Rack::Request.new(env).ip }

    attr_reader :app, :store

    def initialize(app, options = {}, &block)
      @app = app
      @options = options
      @block = block || DEFAULT_BLOCK
      @store = options[:store] || HashStore.new
    end

    def call(env)
      key = client_key(env)
      return app.call(env) if key.nil?

      limit, reset_at = store.get(key) || [nil, nil]

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
      store.set(key, [limit, reset_at]) if key
    end

    def client_key(env)
      @block.call(env)
    end
  end

  class HashStore
    def initialize
      @hash = {}
    end

    def get(key)
      @hash[key]
    end

    def set(key, value)
      @hash[key] = value
    end
  end
end
