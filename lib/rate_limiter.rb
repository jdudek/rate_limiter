require "rate_limiter/version"

module RateLimiter
  class Middleware
    DEFAULT_BLOCK = lambda { |env| Rack::Request.new(env).ip }

    def initialize(app, options = {}, &block)
      @app = app
      @options = options.dup
      @options[:block] = block || DEFAULT_BLOCK
      @options[:store] ||= HashStore.new
      @options[:limit] ||= 60
    end

    def call(env)
      Request.new(@app, @options, env).perform
    end
  end

  class Request
    attr_reader :app, :options, :env

    def initialize(app, options, env)
      @app, @options, @env = app, options, env
    end

    def perform
      if apply_rate_limit?
        if new_client? || expired?
          reset_limit
        end
        if exceeded?
          response_for_limit_exceeded
        else
          call_app_with_limit
        end
      else
        call_app
      end
    end

    protected

    def apply_rate_limit?
      ! key.nil?
    end

    def key
      @key ||= options[:block].call(env)
    end

    def new_client?
      data_from_store.nil?
    end

    def expired?
      expires_at < Time.now
    end

    def exceeded?
      remaining_limit == 0
    end

    def expires_at
      @expires_at ||= data_from_store && data_from_store[:expires_at]
    end

    attr_writer :expires_at

    def remaining_limit
      @remaining_limit ||= data_from_store && data_from_store[:remaining_limit]
    end

    attr_writer :remaining_limit

    def total_limit
      options[:limit]
    end

    def reset_limit
      self.remaining_limit = total_limit
      self.expires_at = Time.now + 3600
    end

    def data_from_store
      options[:store].get(key)
    end

    def store_data
      options[:store].set(key, { expires_at: expires_at, remaining_limit: remaining_limit })
    end

    def response_for_limit_exceeded
      [429, {}, ""]
    end

    def call_app_with_limit
      status, headers, body = app.call(env)
      self.remaining_limit -= 1
      headers["X-RateLimit-Limit"] = total_limit
      headers["X-RateLimit-Remaining"] = remaining_limit
      headers["X-RateLimit-Reset"] = expires_at.to_i
      [status, headers, body]
    ensure
      store_data
    end

    def call_app
      app.call(env)
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
