module RateLimiter
  class Middleware
    DEFAULT_BLOCK = lambda { |env| Rack::Request.new(env).ip }

    def initialize(app, options = {}, &block)
      @app = app
      @options = options.dup
      @options[:block] = block || DEFAULT_BLOCK
      @options[:store] ||= HashStore.new
      @options[:limit] ||= 60
      @options[:reset_in] ||= 3600
    end

    def call(env)
      Request.new(@app, @options, env).perform
    end
  end
end
