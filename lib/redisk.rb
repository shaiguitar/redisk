require 'eventmachine'
require 'digest/sha1'
require 'fileutils'
require 'redisk/config'

module Redisk
  class Server < EventMachine::Connection
    CRLF = "\r\n"
    COMMANDS = {
      :quit => {:params => 0},
      :flushdb => {:params => 0},
      :get => {:params => 1},
      :set => {:params => 2}
    }

    class KeyNotFound < StandardError; end

    class << self
      attr_accessor :db_prefix
      attr_accessor :num_dirs

      def start(options)
        puts "Starting Redisk on port #{options[:port]}"
        Redisk::Server.db_prefix = options[:db_prefix]
        Redisk::Server.num_dirs = options[:num_dirs]
        EventMachine::run {
          EventMachine::start_server options[:host], options[:port], Redisk::Server
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
      elsif obj.is_a?(File)
        send_data "+"
        send_file_data obj.path
        send_data CRLF
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
        puts "Received command #{command} #{args.inspect}"
        self.send method, args
      else
        ok_response
      end
    end

    def redisk_file_path(key, write=false)
      hashed_key = Digest::SHA1.hexdigest(sanitize_key(key))
      hashed_dir = File.join(Redisk::Server.db_prefix, hashed_key.scan(/../)[0..Redisk::Server.num_dirs-1])
      FileUtils.mkdir_p(hashed_dir) if write && !File.exist?(hashed_dir)
      File.join(hashed_dir,hashed_key)
    end

    def redisk_file(key, write=false)
      begin
        File.new(redisk_file_path(key, write), write ? "w" : "r")
      rescue Errno::ENOENT
        raise KeyNotFound
      end
    end

    def redisk_command_get(args=[])
      response redisk_file(args.first)
    rescue KeyNotFound
      response nil
    end

    def redisk_command_set(args=[])
      f = redisk_file(args.first, true)
      f.write(args[1])
      f.close
      ok_response
    end

    def redisk_command_flushdb(args=[])
      chars = %w(0 1 2 3 4 5 6 7 8 9 a b c d e)
      chars.each do |c|
        chars.each do |c2|
          dir = File.join(Redisk::Server.db_prefix, "#{c}#{c2}")
          FileUtils.rm_rf(dir) if File.exist?(dir)
        end
      end
      ok_response
    end
  end
end
