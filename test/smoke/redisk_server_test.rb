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

  def test_simple_exists
    @redis.set("foo", "bar")
    assert @redis.exists("foo")
    assert !@redis.exists("non_existing_foo")
  end

  def test_del
    @redis.set("foo", "bar")
    assert @redis.exists("foo")
    @redis.del("foo")
    assert !@redis.exists("foo")
  end


  def test_simple_set
    @redis.set "foo", "bar"
    assert_equal "bar", @redis.get("foo")
  end

  def test_huge_set
    data = ""
    1024.times { data << "ab" }
    @redis.set "foo", data
    assert_equal 2 * 1024, @redis.get("foo").size
  end

  def test_info
    info = @redis.info
    assert_not_nil info
  end
end
