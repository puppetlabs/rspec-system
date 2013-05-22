require 'ostruct'

module RSpecSystem
  # This class represents a result from a helper command
  class Result < OpenStruct
    # Returns the value of a member.
    def [](name)
      @table[name.to_sym]
    end
  end
end
