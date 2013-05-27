require 'rspec-system'

module RSpecSystem::Helpers
  # Helper object behind RSpecSystem::Helpers#shell
  class Shell < RSpecSystem::Helper
    name 'shell'
    properties :stdout, :stderr, :exit_code

    # Initializer for Shell object.
    #
    # This should be initialized via the helper method, not directly.
    #
    # @api private
    # @param opts [Hash] options hash
    # @param clr [Object] caller object
    # @param block [Proc] code block
    # @see RSpecSystem::Helpers#shell helper method
    def initialize(opts, clr, &block)
      # Defaults
      opts = {
        :c => opts[:command],
        :command => opts[:c],
      }.merge(opts)

      if opts[:c].nil?
        raise "Cannot use shell with no :command or :c option"
      end

      super(opts, clr, &block)
    end

    # Gathers new results by executing the resource action
    def execute
      rspec_system_node_set.run(opts)
    end
  end
end
