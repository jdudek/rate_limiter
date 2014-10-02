require 'test_helper'

class RateLimiterTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    RateLimiter::Middleware.new(empty_app)
  end

  def empty_app
    lambda { |env| [200, {}, "OK"] }
  end

  def test_adds_rate_limit_headers
    get '/'
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]
  end

  def test_decreases_rate_limit_after_request
    get '/'
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]

    get '/'
    assert_equal 58, last_response.headers["X-RateLimit-Limit"]
  end
end
