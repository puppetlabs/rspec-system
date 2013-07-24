require 'rspec-system'

module RSpecSystem::Helpers
  class Snapshot < RSpecSystem::Helper
    name 'snapshot'
    properties :success

    def initialize(opts, clr, &block)
      super(opts, clr, &block)
    end

    # Gathers new results by executing the resource action
    def execute
      ns = rspec_system_node_set

      log.info("snapshot: executed")
      result = ns.snapshot(opts)
      { :success => result }
    end
  end
end
