require 'fileutils'
require 'net/ssh'
require 'net/scp'
require 'rspec-system/node_set/vagrant_base'

module RSpecSystem
  # A NodeSet implementation for Vagrant using the vmware_fusion provider
  class NodeSet::VagrantVmwareFusion < NodeSet::VagrantBase
    PROVIDER_TYPE = 'vagrant_vmware_fusion'

    # Name of provider
    #
    # @return [String] name of the provider as used by `vagrant --provider`
    def vagrant_provider_name
      'vmware_fusion'
    end

    # Adds virtualbox customization to the Vagrantfile
    #
    # @api private
    # @param name [String] name of the node
    # @param options [Hash] customization options
    # @return [String] a series of vbox.customize lines
    def customize_provider(name,options)
      custom_config = ""
      options.each_pair do |key,value|
        next if global_vagrant_options.include?(key)
        case key
        when 'cpus'
          custom_config << "    prov.vmx['numvcpus'] = '#{value}'\n"
        when 'memory'
          custom_config << "    prov.vmx['memsize'] = '#{value}'\n"
        when 'mac'
          custom_config << "    prov.vmx['ethernet0.generatedAddress'] = '#{value}'\n"
        else
          log.warn("Skipped invalid custom option for node #{name}: #{key}=#{value}")
        end
      end
      custom_config
    end
  end
end
