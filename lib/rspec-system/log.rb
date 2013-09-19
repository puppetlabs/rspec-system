require 'logger'

# This log overlay module, provides access to the +log+ method.
module RSpecSystem::Log
  class Logger
    attr_accessor :io

    def initialize(io)
      @io = io
    end

    def debug(text)
      io << bold(color('Debug: ', :blue)) << text << "\n"
    end

    def info(text)
      io << bold('Info: ') << text << "\n"
    end

    def warn(text)
      io << 'Warn: ' << text << "\n"
    end

    def fatal(text)
      io << 'Fatal: ' << text << "\n"
    end

    def unknown(text)
      io << 'Unknown: ' << text << "\n"
    end

    def error(text)
      io << 'Error: ' << text << "\n"
    end
  end

  # Return the default Logger object.
  #
  # @return [Logger] default logger object
  def log
    return @logger if @logger
    @logger = Logger.new(output)
    @logger
  end

  def formatter
    RSpec.configuration.formatters.each do |f|
      if f.is_a? RSpecSystem::Formatter then
        return f
      end
    end
  end

  class NullStream
     def <<(o); self; end
  end

  def output
    begin
      formatter.output
    rescue NameError
      NullStream.new
    end
  end

  def bold(text)
    begin
      formatter.send(:bold, text)
    rescue NameError
      ""
    end
  end

  def color(text, color)
    begin
      formatter.send(:color, text, color)
    rescue NameError
      ""
    end
  end
end
