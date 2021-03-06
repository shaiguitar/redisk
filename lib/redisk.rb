require 'eventmachine'
require 'digest/sha1'
require 'fileutils'
require 'redisk/config'
require 'rubygems'
require 'system_timer'

module Redisk

  VERSION="0.0.1" 

  class Server < EventMachine::Connection
    CRLF = "\r\n"
    COMMANDS = {
      :quit => {:params => 0},
      :flushdb => {:params => 0},
      :flushall => {:params => 0},
      :get => {:params => 1},
      :set => {:params => 1, :extra_read_param => true},
      :del => {:params => 1},
      :exists => {:params => 1},
      :info => {:params => 0}
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

    # client connection happens (EM).
    def post_init
      puts "Client connected!"
      @data = {}
      @command = []
      @in_command = false
      @write_to_file = nil
      @parse_state = :waiting
    end

    # here the client handling is done. http://eventmachine.rubyforge.org/EventMachine/Connection.html#M000269
    # event machine doesn't pass connection data in any sane order/matter, so you need to parse it out here.
    def receive_data(data)
      puts "Received data #{data.inspect}"
      if @parse_state == :write_to_file #in SET.
        @buffer = data
        if @buffer.include?(CRLF)
          line, buffer = @buffer.split(CRLF, 2)
          if line
            @buffer = buffer
            f = File.new(@write_to_file, "a")
            f.write(line)
            f.close
            File.rename(@write_to_file, @write_to_file_target)
            @write_to_file = nil
            @parse_state = :waiting
            response_ok
          end
        else
          f = File.new(@write_to_file, "a")
          f.write(@buffer)
          f.close
          @buffer = ""
        end
        return if @buffer.size == 0
        data = ""
      end
      @buffer ||= ""
      @buffer << data
      line = " "
      while line && line.size > 0 && @buffer
        line, buffer = @buffer.split(CRLF, 2)
        if line && line.size > 0
          @buffer = buffer
          handle_line(line)
        else
          @buffer = buffer
        end
      end
    end
    
    def handle_line(line)
      chars = line.chars.to_a
      if chars.first == "*"
        chars.shift
        @parse_state = :command
        return
      end
      if chars.first == "$"
        chars.shift
        return
      end

      if @parse_state == :write_to_file
        f = File.new(@write_to_file, "a")
        f.write(line)
        f.close
        File.rename(@write_to_file, @write_to_file_target)
        @write_to_file = nil
        @parse_state = :waiting
        response_ok
        return
      end

      case line
      when "quit"
        close_connection
      when "get"
        @command << :get
        @in_command = true
        @parse_state = :read_attributes
      when "set"
        @command << :set
        @in_command = true
        @parse_state = :read_attributes
      when "flushdb"
        @command << :flushdb
        @in_command = true
        @parse_state = :read_attributes
      when "flushall"
        @command << :flushall
        @in_command = true
        @parse_state = :read_attributes
      when "del"
        @command << :del
        @in_command = true
        @parse_state = :read_attributes
      when "exists"
        @command << :exists
        @in_command = true
        @parse_state = :read_attributes
      when "info"
        @command << :info
        @in_command = true
        @parse_state = :read_attributes
      else
        if @parse_state == :read_attributes
          @command << line
        end
      end

      execute_command
    end

    # if right amount of params of passed, run_commnand_x
    def execute_command
      if @command && @command.size > 0
        command_options = COMMANDS[@command.first]
        if command_options && @command.size == command_options[:params] + 1
          @parse_state = :executing
          command = @command.shift
          args = @command
          run_command(command, args)
          @command = []
          @in_command = false
          @parse_state = :wating if @parse_state != :write_to_file
        end
      end
    end

    def sanitize(key)
      key.gsub("\r\n","\\r\\n")
    end

    def unsanitize(key)
      key.gsub("\\r\\n","\r\n")
    end

    # http://code.google.com/p/redis/wiki/ProtocolSpecification
    def response(obj)
      if obj.nil?
        puts "Sent: $-1#{CRLF}"
        send_data "$-1#{CRLF}"
      elsif obj.is_a?(Integer)
        puts "Sent: :#{obj}#{CRLF}"
        send_data ":#{obj}#{CRLF}"
      elsif obj.is_a?(File)
        filesize=File.read(obj.path).size # prob a better way to do this. later.
        puts "Sent: $#{filesize} send-file-data #{CRLF}"
        send_data "$#{filesize}#{CRLF}"
        send_file_data obj.path
        send_data CRLF
      elsif obj.is_a?(String)
        if obj.collect.size > 1
          puts "Sent: $#{obj.size}#{CRLF}#{obj.to_s}#{CRLF}"
          send_data "$#{obj.size}#{CRLF}#{obj.to_s}#{CRLF}"
        else
          puts "Sent: +#{obj.to_s}#{CRLF}"
          send_data "+#{obj.to_s}#{CRLF}"
        end
      end
    end

    def response_ok
      response "OK"
    end

    def redisk_file_path(key, write=false)
      hashed_key = Digest::SHA1.hexdigest(sanitize(key))
      hashed_dir = File.join(Redisk::Server.db_prefix, hashed_key.scan(/../)[0..Redisk::Server.num_dirs-1])
      FileUtils.mkdir_p(hashed_dir) if write && !File.exist?(hashed_dir)
      File.join(hashed_dir,hashed_key)
    end

    def redisk_file(key, write=false, temp=false)
      begin
        if temp
          File.new(redisk_file_path(key, write)+".tmp#{signature}", write ? "w" : "r")
        else
          File.new(redisk_file_path(key, write), write ? "w" : "r")
        end
      rescue Errno::ENOENT
        raise KeyNotFound
      end
    end

    # redis commands hereon out and below.
    def run_command(command, args=[])
      method = "redisk_command_#{command}"
      if self.respond_to?(method)
        puts "Received command #{command} #{args.inspect}"
        self.send method, args
      else
        response_ok
      end
    end

    def redisk_command_get(args=[])
      response redisk_file(args.first)
    rescue KeyNotFound
      response nil
    end

    def redisk_command_set(args=[])
      f = redisk_file(args.first, true, true)
      @write_to_file = f.path
      @write_to_file_target = redisk_file_path(args.first, false)
      f.close
      @parse_state = :write_to_file
    end

    def redisk_command_del(args=[])
      path_for_key = redisk_file_path(args.first)
      if File.exist?(path_for_key) 
        FileUtils.rm(path_for_key) 
        response(1)  #todo handle more than one del X key. 
      else
        response(0)
      end
    end

    def redisk_command_exists(args=[])
      File.exist?(redisk_file_path(args.first)) ? response(1) : response(0)
    end

    def redisk_command_flushdb(args=[])
      chars = %w(0 1 2 3 4 5 6 7 8 9 a b c d e)
      chars.each do |c|
        chars.each do |c2|
          dir = File.join(Redisk::Server.db_prefix || "/tmp", "#{c}#{c2}")
          FileUtils.rm_rf(dir) if File.exist?(dir)
        end
      end
      response_ok
    end

    def redisk_command_flushall(args=[])
      redisk_command_flushdb #for now
    end

    def redisk_command_info(args=[])
      info = <<-EOF
redis_version:REDISK-#{Redisk::VERSION}
connected_clients:1
connected_slaves:0
used_memory:3187
changes_since_last_save:0
last_save_time:1237655729
total_connections_received:1
total_commands_processed:1
uptime_in_seconds:25
uptime_in_days:0
EOF
      info.gsub!(/\n/, CRLF)
      response info
    end
  end
end
