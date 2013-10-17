module RSpecSystem
  # Factory class for NodeSet.
  class NodeSet
    # Returns a NodeSet object.
    #
    # @return [RSpecSystem::NodeSet::Base] returns an object based on the Base
    #   abstract class.
    def self.create(setname, config, virtual_env, custom_prefabs_path, options)
      begin
        require "rspec-system/node_set/#{virtual_env.downcase}"
      rescue LoadError => e
        raise "Unsupported virtual environment #{virtual_env}: #{e}"
      end
      const_get(virtual_env.capitalize).new(setname, config, custom_prefabs_path, options)
    end
  end
end
