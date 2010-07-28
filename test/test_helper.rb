require 'test/unit'
require 'redis'
require 'system_timer'

class Test::Unit::TestCase
  REDISK_TEST_PORT = 18913
  def start_server
    @server = fork do
      $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
      require 'redisk'
      config = Redisk::Config.new([])
      config.options[:port] = REDISK_TEST_PORT
      Redisk::Server.start(config.options)
    end
    sleep 1
  end

  def stop_server
    Process.kill("TERM", @server)
    @server = nil
    sleep 1
  end
end
