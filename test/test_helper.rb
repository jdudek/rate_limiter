require 'minitest/autorun'
require 'rack/test'
require 'rate_limiter'
require 'time'
require 'timecop'
require 'mocha/mini_test'

class RateLimiterTestCase < Minitest::Test
  def empty_app
    lambda { |env| [200, {}, "OK"] }
  end

  def at_time(time, &block)
    Timecop.travel(Time.parse(time), &block)
  end

  def timestamp_for(time)
    Time.parse(time).to_i.to_s
  end
end
