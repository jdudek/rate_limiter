require 'test_helper'

class RateLimiterTest < RateLimiterTestCase
  include Rack::Test::Methods

  def teardown
    @app = nil
  end

  def app
    @app ||= build_app
  end

  def build_app(options = {}, &block)
    Rack::Builder.app do
      use Rack::Lint
      use RateLimiter::Middleware, options, &block
      run lambda { |env| [200, {}, ["OK"]] }
    end
  end

  def test_adds_rate_limit_headers
    get '/'
    assert_equal "60", last_response.headers["X-RateLimit-Limit"]
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]
    assert last_response.headers["X-RateLimit-Reset"]
  end

  def test_decreases_rate_limit_after_request
    get '/'
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]

    get '/'
    assert_equal "58", last_response.headers["X-RateLimit-Remaining"]
  end

  def test_returns_429_when_limit_exceeded
    60.times { get '/' }
    assert_equal "0", last_response.headers["X-RateLimit-Remaining"]

    get '/'
    assert_equal 429, last_response.status
  end

  def test_resets_rate_limit_each_full_hour
    at_time "2:00" do
      10.times { get '/' }
      assert_equal "50", last_response.headers["X-RateLimit-Remaining"]
      assert_equal timestamp_for("3:00"), last_response.headers["X-RateLimit-Reset"]
    end

    at_time "3:10" do
      get '/'
      assert_equal "59", last_response.headers["X-RateLimit-Remaining"]
      assert_equal timestamp_for("4:10"), last_response.headers["X-RateLimit-Reset"]
    end
  end

  def test_has_separate_limit_for_ip
    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]

    get '/', {}, "REMOTE_ADDR" => "10.0.0.2"
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]

    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
    assert_equal "58", last_response.headers["X-RateLimit-Remaining"]
  end

  def test_custom_client_detection
    @app = RateLimiter::Middleware.new(empty_app) { |env| Rack::Request.new(env).params["api_token"] }

    get '/', { "api_token" => "abc123" }
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]

    get '/', { "api_token" => "def456" }
    assert_equal "59", last_response.headers["X-RateLimit-Remaining"]

    get '/', { "api_token" => "abc123" }
    assert_equal "58", last_response.headers["X-RateLimit-Remaining"]
  end

  def test_no_rate_limit_when_block_returns_nil
    @app = build_app { |env| nil }

    get '/', { "api_token" => "abc123" }
    assert_nil last_response.headers["X-RateLimit-Remaining"]
  end

  def test_custom_store
    store = mock
    @app = build_app(store: store)

    store.expects(:get).returns(nil)
    store.expects(:set)

    get '/', {}, "REMOTE_ADDR" => "10.0.0.1"
  end
end
