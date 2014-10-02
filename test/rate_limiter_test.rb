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
    assert_equal "60", last_response.headers["X-RateLimit-Limit"]
  end
end
