module RSpecSystem
  # Factory class for NodeSet.
  class NodeSet
    # Returns a NodeSet object.
    #
    # @return [RSpecSystem::NodeSet::Base] returns an object based on the Base
    #   abstract class.
    # @api private
    def self.create
      provider = RSpec.configuration.rs_provider
      custom_prefabs = RSpec.configuration.rs_custom_prefabs
      setname = RSpec.configuration.rs_set || RSpec.configuration.rs_config['default_set']
      options = {:destroy => RSpec.configuration.rs_destroy}
      config = RSpec.configuration.rs_config['sets'][setname]

      begin
        require "rspec-system/node_set/#{provider.downcase}"
      rescue LoadError => e
        raise "Unsupported provider #{provider}: #{e}"
      end
      class_name = provider.split("_").map {|v| v.capitalize }.join
      const_get(class_name).new(setname, config, custom_prefabs, options)
    end
  end
end
