module RateLimiter
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
