module RSpecSystem
  # This class represents a node in a nodeset
  class Node
    # Static helper for generating a node direct from the hash returned by
    # the nodeset YAML file.
    #
    # @param nodeset [RSpecSystem::Node] nodeset that this node belongs to
    # @param k [String] name of node
    # @param v [Hash<String,String>] hash configuration as given from the nodeset yaml file
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @return [RSpecSystem::Node] returns a new node object
    def self.node_from_yaml(nodeset, k, v, custom_prefabs_path)
      RSpecSystem::Node.new(
        :nodeset => nodeset,
        :custom_prefabs_path => custom_prefabs_path,
        :name => k,
        :prefab => v['prefab']
      )
    end

    # Create a new node object.
    #
    # @param options [Hash] options for new node
    # @option options [String] :name name of node. Mandatory.
    # @option options [String] :prefab prefab setting. Mandatory.
    # @option options [RSpecSystem::NodeSet] :nodeset the parent nodeset for
    #   this node. Mandatory.
    # @option options [String] :custom_prefabs_path path of custom prefabs
    #   yaml file. Optional.
    def initialize(options)
      @name = options[:name]
      prefab = options[:prefab]
      @nodeset = options[:nodeset]
      @custom_prefabs_path = options[:custom_prefabs_path]

      if prefab.nil?
        # TODO: do not support not prefabs yet
        raise "No prefab defined, bailing"
      else
        @prefab = RSpecSystem::Prefab.prefab(prefab, custom_prefabs_path)
        @facts = @prefab.facts
        @provider_specifics = @prefab.provider_specifics
      end
    end

    # Returns the name of the node as specified in the nodeset file.
    #
    # @return [String] name of node
    def name
      @name
    end

    # Returns the prefab object for this node (if any).
    #
    # @return [RSpecSystem::Prefab] the prefab object used to create this node
    def prefab
      @prefab
    end

    # Retreives facts from the nodeset definition or prefab.
    #
    # @return [Hash] returns a hash of facter facts defined for this node
    def facts
      @facts
    end

    # Returns the nodeset this node belongs in.
    #
    # @return [RSpecSystem::NodeSet] the nodeset this node belongs to
    def nodeset
      @nodeset
    end

    # Return provider specific settings
    #
    # @return [Hash] provider specific settings
    def provider_specifics
      @provider_specifics
    end
  end
end
