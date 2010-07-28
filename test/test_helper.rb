require 'test/unit'
require 'redis'
require 'system_timer'

class Test::Unit::TestCase
  def start_server
    @server = fork do
      load "bin/redisk"
    end
    sleep 1
  end

  def stop_server
    Process.kill("TERM", @server)
    @server = nil
    sleep 1
  end
end
