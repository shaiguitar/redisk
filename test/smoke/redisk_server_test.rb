require 'test_helper'

class RediskServerTest < Test::Unit::TestCase
  def setup
    @redis = Redis.new(:port => 6380)
  end

  def test_simple_get
    assert_nil @redis.get("foo")
  end

  def test_simple_set
    @redis.set "foo", "bar"
    assert_equal "bar", @redis.get("foo")
  end
end
