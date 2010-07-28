require 'optparse'

module Redisk
  class Config
    def initialize(argv)
    options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: redisk [options]"

        # pass yaml with port, host, path_prefix options
        opts.on( '-c', '--config-file [/path/to/config.yml]', "Config file" ) do |c|
          require 'yaml'
          options.merge!(YAML.load_file(c))
        end

        options[:port] = 6380
        opts.on( '-p', '--port [NUM]', Integer, "Port to run redisk" ) do |p|
          options[:port] = p
        end

        options[:host] = '127.0.0.1'
        opts.on( '-h', '--host [ip.of.red.isk]', "Port to run redisk" ) do |h|
          options[:host] = h
        end

        options[:path_prefix] =  '/tmp/'
        opts.on( '-P', '--prefix [/path/to/store]', "Prefix path for Redisk" ) do |p|
          options[:path_prefix] = p
        end

      end.parse!
      p options
      p ARGV
    end
  end
end
