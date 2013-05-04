module RSpecSystem
  # Factory class for NodeSet.
  class NodeSet
    # Returns a NodeSet object.
    #
    # @return [RSpecSystem::NodeSet::Base] returns an object based on the Base
    #   abstract class.
    def self.create(setname, config, virtual_env)
      case(virtual_env)
      when 'vagrant'
        RSpecSystem::NodeSet::Vagrant.new(setname, config)
      when 'vsphere'
        RSpecSystem::NodeSet::Vsphere.new(setname, config)
      else
        raise "Unsupported virtual environment #{virtual_env}"
      end
    end
  end
end

require 'rspec-system/node_set/base'
require 'rspec-system/node_set/vagrant'
require 'rspec-system/node_set/vsphere'
