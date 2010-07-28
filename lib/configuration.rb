require 'optparse'

module Redisk
  class Config
    attr_accessor :options
    def initialize(argv)
    @options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: redisk -c redisk.yml -p [port] -h [host] -P [db_prefix]"

        # pass yaml with port, host, path_prefix @options
        opts.on( '-c', '--config-file [/path/to/config.yml]', "Config file" ) do |c|
          require 'yaml'
          @options.merge!(YAML.load_file(c))
        end

        @options[:port] = 6380
        opts.on( '-p', '--port [NUM]', Integer, "Port to run redisk" ) do |p|
          @options[:port] = p
        end

        @options[:host] = '127.0.0.1'
        opts.on( '-h', '--host [ip.of.red.isk]', "Port to run redisk" ) do |h|
          @options[:host] = h
        end

        @options[:db_prefix] =  '/tmp/'
        opts.on( '-P', '--prefix [/path/to/store]', "Prefix path for Redisk" ) do |p|
          @options[:db_prefix] = p
        end

        @options[:num_dirs] =  2
        opts.on( '-D', '--num-dirs [num_dirs]', [1,2,3], "Directory hashing levels (1,2 or 3)" ) do |n|
          @options[:num_dirs] = n
        end

      end.parse!
    end
  end
end
