require 'test_helper'

class RateLimiterTest < Minitest::Unit::TestCase
  include Rack::Test::Methods

  def teardown
    @app = nil
  end

  def app
    @app ||= RateLimiter::Middleware.new(empty_app)
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

  def test_returns_429_when_limit_exceeded
    60.times { get '/' }
    assert_equal 0, last_response.headers["X-RateLimit-Limit"]

    get '/'
    assert_equal 429, last_response.status
  end

  def test_resets_rate_limit_each_full_hour
    at_time "2:00" do
      10.times { get '/' }
      assert_equal 50, last_response.headers["X-RateLimit-Limit"]
    end

    at_time "3:10" do
      get '/'
      assert_equal 59, last_response.headers["X-RateLimit-Limit"]
    end
  end

  def test_has_separate_limit_for_ip
    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]

    get '/', {}, "REMOTE_ADDR" => "10.0.0.2"
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]

    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
    assert_equal 58, last_response.headers["X-RateLimit-Limit"]
  end

  def test_custom_client_detection
    @app = RateLimiter::Middleware.new(empty_app) { |env| Rack::Request.new(env).params["api_token"] }

    get '/', { "api_token" => "abc123" }
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]

    get '/', { "api_token" => "def456" }
    assert_equal 59, last_response.headers["X-RateLimit-Limit"]

    get '/', { "api_token" => "abc123" }
    assert_equal 58, last_response.headers["X-RateLimit-Limit"]
  end

  def test_no_rate_limit_when_block_returns_nil
    @app = RateLimiter::Middleware.new(empty_app) { |env| nil }

    get '/', { "api_token" => "abc123" }
    assert_nil last_response.headers["X-RateLimit-Limit"]
  end

  def test_custom_store
    store = mock
    @app = RateLimiter::Middleware.new(empty_app, store: store )

    store.expects(:get).returns(nil)
    store.expects(:set)

    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
  end

  def at_time(time, &block)
    Timecop.travel(Time.parse(time), &block)
  end
end
