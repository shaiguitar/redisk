require 'test_helper'

class RediskServerTest < Test::Unit::TestCase
  def setup
    start_server
    @redis = Redis.new(:port => REDISK_TEST_PORT)
    @redis.flushdb
  end

  def teardown
    stop_server
  end

  def test_simple_get
    assert_nil @redis.get("foo")
  end

  def test_simple_set
    @redis.set "foo", "bar"
    assert_equal "bar", @redis.get("foo")
  end
end
