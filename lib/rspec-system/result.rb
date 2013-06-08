require 'rspec-system'
require 'ostruct'

module RSpecSystem
  # This class represents raw results from a helper command
  class Result < OpenStruct
    # Returns the value of a member, with hash syntax.
    #
    # @param name [String, Symbol] name of parameter to retrieve
    def [](name)
      @table[name.to_sym]
    end

    # Return a hash
    #
    # @return [Hash] a hash representation of the results
    def to_hash
      @table
    end
  end
end
