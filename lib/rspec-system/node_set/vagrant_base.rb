require 'fileutils'
require 'net/ssh'
require 'net/scp'
require 'rspec-system/node_set/base'

module RSpecSystem
  # An abstract NodeSet implementation for Vagrant.
  class NodeSet::VagrantBase < RSpecSystem::NodeSet::Base
    include RSpecSystem::Log
    include RSpecSystem::Util

    # @!group Abstract Methods

    # The vagrant specific provider name
    #
    # @return [String] name of the provider as used by `vagrant --provider`
    # @abstract override to return the name of the vagrant provider
    def vagrant_provider_name
      raise RuntimeError, "Unimplemented method #vagrant_provider_name"
    end

    # @!group Common Methods

    # Creates a new instance of RSpecSystem::NodeSet::Vagrant
    #
    # @param setname [String] name of the set to instantiate
    # @param config [Hash] nodeset configuration hash
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @param options [Hash] options Hash
    def initialize(setname, config, custom_prefabs_path, options)
      super
      @vagrant_path = File.expand_path(File.join(RSpec.configuration.rs_tmp, 'vagrant_projects', setname))

      RSpec.configuration.rs_storage[:nodes] ||= {}
    end

    # Launch the nodes
    #
    # @return [void]
    def launch
      create_vagrantfile()

      teardown()

      nodes.each do |k,v|
        RSpec.configuration.rs_storage[:nodes][k] ||= {}
        output << bold(color("localhost$", :green)) << " vagrant up #{k}\n"
        vagrant("up #{k} --provider=#{vagrant_provider_name}")
      end

      nil
    end

    # Connect to the nodes
    #
    # @return [void]
    def connect
      nodes.each do |k,v|
        RSpec.configuration.rs_storage[:nodes][k] ||= {}

        chan = ssh_connect(:host => k, :user => 'vagrant', :net_ssh_options => {
          :config => ssh_config
        })

        # Copy the authorized keys from vagrant user to root then reconnect
        cmd = 'mkdir /root/.ssh ; cp /home/vagrant/.ssh/authorized_keys /root/.ssh'

        output << bold(color("#{k}$ ", :green)) << cmd << "\n"
        ssh_exec!(chan, "cd /tmp && sudo sh -c #{shellescape(cmd)}")

        chan = ssh_connect(:host => k, :user => 'root', :net_ssh_options => {
          :config => ssh_config
        })
        RSpec.configuration.rs_storage[:nodes][k][:ssh] = chan
      end

      nil
    end

    # Shutdown the NodeSet by shutting down or pausing all nodes.
    #
    # @return [void]
    def teardown
      nodes.each do |k,v|
        storage = RSpec.configuration.rs_storage[:nodes][k]

        next if storage.nil?

        ssh = storage[:ssh]
        ssh.close unless ssh.closed?
      end

      if destroy
        output << bold(color("localhost$", :green)) << " vagrant destroy --force\n"
        vagrant("destroy --force")
      end

      nil
    end

    # Create the Vagrantfile for the NodeSet.
    #
    # @api private
    def create_vagrantfile
      output << bold(color("localhost$", :green)) << " cd #{@vagrant_path}\n"
      FileUtils.mkdir_p(@vagrant_path)
      File.open(File.expand_path(File.join(@vagrant_path, "Vagrantfile")), 'w') do |f|
        f.write('Vagrant.configure("2") do |c|' + "\n")
        nodes.each do |k,v|
          ps = v.provider_specifics[provider_type]
          default_options = { 'mac' => randmac }
          options = default_options.merge(v.options || {})

          node_config = "  c.vm.define '#{k}' do |v|\n"
          node_config << "    v.vm.hostname = '#{k}'\n"
          node_config << "    v.vm.box = '#{ps['box']}'\n"
          node_config << "    v.vm.box_url = '#{ps['box_url']}'\n" unless ps['box_url'].nil?
          node_config << "    v.vm.synced_folder #{ps['synced_folder']}\n" unless ps['synced_folder'].nil?
          node_config << customize_vm(k,options)
          node_config << "    v.vm.provider '#{vagrant_provider_name}' do |prov, override|\n"
          node_config << customize_provider(k,options)
          node_config << "    end\n"
          node_config << "  end\n"

          f.write(node_config)
        end
        f.write("end\n")
      end
      nil
    end

    # Add provider specific customization to the Vagrantfile
    #
    # @api private
    # @param name [String] name of the node
    # @param options [Hash] customization options
    # @return [String] a series of prov.customize lines
    # @abstract Overridet ot provide your own customizations
    def customize_provider(name,options)
      ''
    end

    # Adds VM customization to the Vagrantfile
    #
    # @api private
    # @param name [String] name of the node
    # @param options [Hash] customization options
    # @return [String] a series of v.vm lines
    def customize_vm(name,options)
      vm_config = ""
      options.each_pair do |key,value|
        case key
        when 'ip'
          vm_config << "    v.vm.network :private_network, :ip => '#{value}'\n"
        else
          next
        end
      end
      vm_config
    end

    # Run a system command with a "clean" env, even if running under Bundler
    #
    # @api private
    def clean_system(*args)
      if defined?(Bundler)
        Bundler.clean_system(*args)
      else
        system(*args)
      end
    end

    # Here we get vagrant to drop the ssh_config its using so we can monopolize
    # it for transfers and custom stuff. We drop it into a single file, and
    # since its indexed based on our own node names its quite ideal.
    #
    # @api private
    # @return [String] path to ssh_config file
    def ssh_config
      ssh_config_path = File.expand_path(File.join(@vagrant_path, "ssh_config"))
      begin
        File.unlink(ssh_config_path)
      rescue Errno::ENOENT
      end

      self.nodes.each do |k,v|
        Dir.chdir(@vagrant_path) do
          clean_system("vagrant ssh-config #{k} >> #{ssh_config_path}")
        end
      end
      ssh_config_path
    end

    # Execute vagrant command in vagrant_path
    #
    # @api private
    # @param args [String] args to vagrant
    def vagrant(args)
      Dir.chdir(@vagrant_path) do
        clean_system("vagrant #{args}")
      end
      nil
    end

    # Returns a list of options that apply to all types of vagrant providers
    #
    # @return [Array<String>] Array of options
    # @api private
    def global_vagrant_options
      ['ip']
    end

  end
end
