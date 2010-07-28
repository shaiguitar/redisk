require 'test_helper'

class RedisProtocolTest < Test::Unit::TestCase
  def setup
    @conn = Redisk::Server.new("foo")
    @conn.post_init
    @buffer = ""
    def @conn.run_command(command, args=[])
      @last_command = [command, *args]
    end
  end

  def test_simple_redis_command
    @conn.receive_data("*1\r\n")
    @conn.receive_data("$7\r\n")
    @conn.receive_data("flushdb\r\n")

    assert_equal [:flushdb], @conn.instance_variable_get("@last_command")
  end
  
  def test_complex_redis_commands
    @conn.receive_data("*2\r\n")
    @conn.receive_data("$3\r\n")
    @conn.receive_data("get\r\n")
    @conn.receive_data("$3\r\n")
    @conn.receive_data("foo\r\n")

    assert_equal [:get, "foo"], @conn.instance_variable_get("@last_command")
  end

end
