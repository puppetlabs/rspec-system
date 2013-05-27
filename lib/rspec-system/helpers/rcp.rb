require 'rspec-system'

module RSpecSystem::Helpers
  # Helper object behind RSpecSystem::Helpers#shell
  class Rcp < RSpecSystem::Helper
    name 'rcp'
    properties :success

    def initialize(opts, clr, &block)
      ns = rspec_system_node_set
      opts = {
        :source_path => opts[:sp],
        :destination_path => opts[:dp],
        :dp => opts[:destination_path],
        :sp => opts[:source_path],
        :destination_node => ns.default_node,
        :d => ns.default_node,
        :source_node => nil,
        :s => nil,
      }.merge(opts)

      super(opts, clr, &block)
    end

    # Gathers new results by executing the resource action
    def execute
      ns = rspec_system_node_set
      d = opts[:d]
      sp = opts[:sp]
      dp = opts[:dp]

      log.info("rcp from #{sp} to #{d.name}:#{dp} executed")
      result = ns.rcp(opts)
      { :success => result }
    end
  end
end
