require 'eventmachine'

module Redisk
  class Server < EventMachine::Connection
    PORT = 6380
    CRLF = "\r\n"
    COMMANDS = {
      :quit => {:params => 0},
      :flushdb => {:params => 0},
      :get => {:params => 1},
      :set => {:params => 2}
    }

    class << self
      def start(options)
        puts "Starting Redisk on port #{PORT}"
        EventMachine::run {
          EventMachine::start_server "127.0.0.1", PORT, Redisk::Server
        }
      end
    end

    def post_init
      @data = {}
      @command = []
      @in_command = false
    end

    # if right amount of params of passed, run_commnand_x
    def execute_command
      if @command && @command.size > 0
        command_options = COMMANDS[@command.first]
        if command_options && @command.size == command_options[:params] + 1
          p @command
          command = @command.shift
          args = @command
          run_command command, args
          @command = []
          @in_command = false
        end
      end
    end

    def handle_line(line)
      return if line.chars.first == "$"
      case line
      when "quit"
        close_connection
      when "get"
        @command << :get
        @in_command = true
      when "set"
        @command << :set
        @in_command = true
      when "flushdb"
        @command << :flushdb
        @in_command = true
      else
        if @in_command
          @command << line
        end
      end

      execute_command
    end

    def receive_data(data)
      @buffer ||= ""
      @buffer << data
      line = " "
      while line && line.size > 0
        line, buffer = @buffer.split(CRLF, 2)
        if line
          @buffer = buffer
          handle_line line
        end
      end
    end

    def sanitize_key(key)
      key
    end

    def response(obj)
      if obj.nil?
        send_data "$-1#{CRLF}"
      else
        send_data "+#{obj.to_s}#{CRLF}"
      end
    end

    def ok_response
      response "OK"
    end

    def run_command(command, args=[])
      method = "redisk_command_#{command}"
      if self.respond_to?(method)
        self.send method, args
      else
        ok_response
      end
    end

    def redisk_command_get(args=[])
      response @data[sanitize_key(args.first)]
    end

    def redisk_command_set(args=[])
      require 'digest/sha1'
      hashed_key = Digest::SHA1.hexdigest(sanitize_key(args.first))
      File.new(hashed_key, "w").write(args[1])
      @data[sanitize_key(args.first)] = args[1]
      ok_response
    end

    def redisk_command_flushdb(args=[])
      ok_response
    end
  end
end
