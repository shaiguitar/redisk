require 'eventmachine'

module Redisk
  class Server < EventMachine::Connection
    PORT = 6380
    class << self
      def start
        puts "Starting Redisk on port #{PORT}"
        EventMachine::run {
          EventMachine::start_server "127.0.0.1", PORT, Redisk::Server
        }
      end
    end

    def receive_data data
      send_data ">>>you sent: #{data}"
      close_connection if data =~ /quit/i
    end
  end
end
