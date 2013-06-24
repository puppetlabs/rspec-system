require 'rspec-system'

module RSpecSystem::Exception
  # Parent for all RSpecSystem exceptions
  class Error < StandardError; end

  # General timeout error
  class TimeoutError < Error; end
end
