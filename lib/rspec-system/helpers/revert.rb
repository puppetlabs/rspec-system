require 'rspec-system'

module RSpecSystem::Helpers
  class Revert < RSpecSystem::Helper
    name 'revert'
    properties :success

    def initialize(opts, clr, &block)
      super(opts, clr, &block)
    end

    # Gathers new results by executing the resource action
    def execute
      ns = rspec_system_node_set

      log.info("revert: executed")
      result = ns.revert(opts)
      { :success => result }
    end
  end
end
