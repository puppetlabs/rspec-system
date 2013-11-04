require 'rspec-system'

module RSpecSystem::Helpers
  # Helper object behind RSpecSystem::Helpers#shell
  class Rcp < RSpecSystem::Helper
    name 'rcp'
    properties :success

    def initialize(opts, clr, &block)
      ns = RSpecSystem::NodeSet.create
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

      # Try to figure out :*_node using the node helper if a string is passed
      if opts[:destination_node].is_a? String
        opts[:d] = opts[:destination_node] = get_node_by_name(opts[:destination_node])
      end
      if opts[:source_node].is_a? String
        opts[:s] = opts[:source_node] = get_node_by_name(opts[:source_node])
      end

      super(opts, clr, &block)
    end

    # Gathers new results by executing the resource action
    def execute
      ns = RSpecSystem::NodeSet.create

      result = ns.rcp(opts)
      { :success => result }
    end
  end
end
