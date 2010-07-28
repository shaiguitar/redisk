require 'eventmachine'

module Redisk
  class Server < EventMachine::Connection
    PORT = 6380
    CRLF = "\r\n"

    class << self
      def start
        puts "Starting Redisk on port #{PORT}"
        EventMachine::run {
          EventMachine::start_server "127.0.0.1", PORT, Redisk::Server
        }
      end
    end

    def receive_data(data)
      @buffer ||= ""
      @buffer << data
      command = " "
      while command && command.size > 0
        command, buffer = @buffer.split(CRLF, 2)
        if command
          puts "received command #{command}"
          @buffer = buffer
          close_connection if command =~ /QUIT/i
        end
      end
    end
  end
end
