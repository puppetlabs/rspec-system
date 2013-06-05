require "rspec/core/formatters/base_text_formatter"

module RSpecSystem
  # This custom formatter is designed for rspec-system test presentation
  #
  # Because rspec-system tests are often wordier and require lots of diagnostic
  # information to be enabled for future debugging, the traditional document
  # and progress formatters just simply aren't sufficient.
  #
  # This formatter instead treats each test as a document section, splitting
  # up the output with obvious breaks so the user can clearly see when a test
  # has started and finished. It also attempts to use color for visibility
  # as well as listing test case information in a more verbose way.
  class Formatter < RSpec::Core::Formatters::BaseTextFormatter
    # Initialize formatter
    def initialize(output)
      super(output)
    end

    # Display test start information
    #
    # @param count [Fixnum] number of tests to run
    # @return [void]
    def start(count)
      @max_tests = count
      super(count)
      output << "=================================================================\n\n"
      output << bold("Commencing rspec-system tests\n")
      output << bold("Total Test Count: ") << color(count, :cyan) << "\n\n"
    end

    # Display output when an example has started
    #
    # @param example [RSpec::Core::Example] example that is running
    # @return [void]
    def example_started(example)
      super(example)
      output << "=================================================================\n\n"
      output << bold("Running test: ") << "#{next_index} of #{@max_tests}" << "\n"
      output << bold("Description:\n  ") << color(example.full_description, :magenta) << "\n\n"
    end

    # Display output when an example has passed
    #
    # @param example [RSpec::Core::Example] example that is running
    # @return [void]
    def example_passed(example)
      super(example)
      output << "\n" << bold('Result: ') << success_color('passed') << "\n\n"
    end

    # Display output when an example is pending
    #
    # @param example [RSpec::Core::Example] example that is running
    # @return [void]
    def example_pending(example)
      super(example)
      msg = example.execution_result[:pending_message]
      output << "\n" << bold('Result: ') << pending_color('pending') << "\n"
      output << bold("Reason: ") << "#{msg}\n\n"
    end

    # Display output when an example has failed
    #
    # @param example [RSpec::Core::Example] example that is running
    # @return [void]
    def example_failed(example)
      super(example)
      msg = example.execution_result[:exception]
      output << "\n" << bold('Result: ') << failure_color('failed') << "\n"
      output << bold("Reason:\n") << "#{msg}\n\n"
    end

    # Obtains next index value so we can keep a count of what test we are upto
    #
    # @api private
    # @return [Fixnum] index #
    def next_index
      @next_index ||= 0
      @next_index += 1
    end
  end
end
