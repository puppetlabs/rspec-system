require 'rspec-system'
require 'rspec-system/result'
require 'rspec-system/internal_helpers'
require 'timeout'

module RSpecSystem
  # This class represents an abstract 'helper' object.
  #
  # It provides some DSL and convenience helpers to create rspec-system
  # compatible helper objects so others can create their own helper methods
  # with the same syntactical sugar.
  #
  # Start by sub-classing this feature and providing your own #execute
  # method, name & properties declaration. See other sub-classes for examples
  # on proper usage.
  #
  # @abstract Subclass and override methods to create a helper object
  class Helper
    include RSpecSystem::InternalHelpers

    # Cache of previous result data
    # @api private
    attr_reader :rd

    # Options when called
    attr_reader :opts

    class << self
      attr_accessor :name_value

      # DSL method for setting the helper name
      #
      # @param name [String] unique helper method name
      def name(name)
        @name_value = name
      end

      # Accepts a list of properties to automatically create
      #
      # @param props [Array <Symbol>] an array of property methods to create
      def properties(*props)
        props.each do |prop|
          define_method(prop) { result_data.send(prop) }
        end
      end
    end

    # Setup the helper object.
    #
    # Here we establish laziness detection, provide the default :node setting
    # and handle been called as a block automatically for the consumer. This is
    # the main setup for the magic that is behind these helper objects.
    #
    # This initialize method is usually not overridden for simple cases, but can
    # be overridden for the purposes of munging options and providing defaults.
    #
    # @abstract Override, but make sure you call super(opts, clr, &block)
    def initialize(opts, clr, &block)
      dn = default_node

      # This is a test for the context of how this command was called
      #
      # If clr is Class or Object then it could be called as a subject, and it
      # should lazy execute its action.
      lazy = nil
      if [Class, Object].include?(clr.class) # presumes being used as a subject
        lazy = true
      elsif clr.is_a? RSpec::Core::ExampleGroup # anything inside an 'it'
        lazy = false
      else
        # We presume everything else wants results immediately
        lazy = false
      end

      # Merge defaults and such
      @opts = {
        :node => opts[:n] || dn,
        :n => opts[:node] || dn,
        :timeout => opts[:timeout] || 0,
        :lazy => lazy,
      }.merge(opts)

      # Try to figure out :node using the node helper if a string is passed
      if @opts[:node].is_a? String
        @opts[:n] = @opts[:node] = get_node_by_name(@opts[:node])
      end

      # Try to lookup result_data now, unless we are lazy
      result_data unless @opts[:lazy]

      # If called as a block, yield the result as a block
      if block_given?
        yield(self)
      end
    end

    # This method is executed to retrieve the data for this helper. It is always
    # overridden by sub-classes.
    #
    # Here we perform the actual step to retrieve the helper data, returning
    # the result as a basic hash which gets stored for later retrieval via the
    # helper object.
    #
    # @return [Hash <Symbol, Any>] return a hash of results, with symbolic keys
    # @abstract Always override this method with your own execution routine.
    def execute
      raise "The #execute method has not be overridden in this class"
    end

    # Internal method to return any result data from resource execution time
    #
    # If there are no previous results, it will execute the resource action
    # and return those result. The action only runs once, so subsequent
    # requests return the last result.
    #
    # @return [RSpecSystem::Result] result object
    # @api private
    def result_data
      return rd unless rd.nil?

      begin
        Timeout::timeout(opts[:timeout]) do
          @rd = RSpecSystem::Result.new(execute)
        end
      rescue Timeout::Error => e
        raise RSpecSystem::Exception::TimeoutError, e.message
      end
    end

    # Refresh the data, re-running the action associated with this helper.
    #
    # @return [void]
    def refresh
      @rd = nil
      result_data
      nil
    end

    # Allow run as an alias to refresh
    alias_method :run, :refresh

    # This allows the data to be treated as a hash
    #
    # @param key [Symbol] key of value to retrieve
    def [](key)
      result_data[key]
    end

    # Retrieve the data from this helper object as a hash
    #
    # @return [Hash] result data as a hash
    def to_hash
      result_data.to_hash
    end

    # Return the helper name of this helper object
    #
    # @return [String] name of helper
    def name
      self.class.name_value
    end

    # String representation of helper
    #
    # @return [String] helper_name(args) formatted string
    def to_s
      name + "(" + opts.inspect + ")"
    end

    # Return default node
    def default_node
      rspec_system_node_set.default_node
    end

    # Returns a node by its name.
    #
    # To be used by helpers that wish to retrieve a node by its name.
    #
    # @param name [String] name of the node
    # @return [RSpecSystem::Node] node found
    def get_node_by_name(name)
      rspec_system_node_set.nodes[name]
    end
  end
end
