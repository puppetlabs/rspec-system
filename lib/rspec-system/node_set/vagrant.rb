require 'fileutils'
require 'systemu'
require 'net/ssh'

module RSpecSystem
  # A NodeSet implementation for Vagrant.
  class NodeSet::Vagrant < RSpecSystem::NodeSet::Base
    include RSpecSystem::Log
    include RSpecSystem::Util

    ENV_TYPE = 'vagrant'

    # Creates a new instance of RSpecSystem::NodeSet::Vagrant
    #
    # @param setname [String] name of the set to instantiate
    # @param config [Hash] nodeset configuration hash
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @param options [Hash] options Hash
    def initialize(setname, config, custom_prefabs_path, options)
      super
      @vagrant_path = File.expand_path(File.join(RSpec.configuration.system_tmp, 'vagrant_projects', setname))
    end

    # Setup the NodeSet by starting all nodes.
    #
    # @return [void]
    def setup
      log.info "[Vagrant#setup] Begin setting up vagrant"

      create_vagrantfile()

      teardown()

      log.info "[Vagrant#setup] Running 'vagrant up'"
      vagrant("up")

      # Establish ssh connectivity
      ssh_channels = {}
      nodes.each do |k,v|
        log.info "[Vagrant#setup] establishing Net::SSH channel with #{k}"
        chan = Net::SSH.start(k, 'vagrant', :config => ssh_config)
        ssh_channels[k] = chan
      end
      RSpec.configuration.ssh_channels = ssh_channels

      nil
    end

    # Shutdown the NodeSet by shutting down or pausing all nodes.
    #
    # @return [void]
    def teardown
      log.info "[Vagrant#teardown] closing all ssh channels"
      RSpec.configuration.ssh_channels.each do |k,v|
        v.close unless v.closed?
      end

      if destroy
        log.info "[Vagrant#teardown] Running 'vagrant destroy'"
        vagrant("destroy --force")
      else
        log.info "[Vagrant#teardown] Skipping 'vagrant destroy'"
      end
      nil
    end

    # Run a command on a host in the NodeSet.
    #
    # @param opts [Hash] options
    # @return [Hash] a hash containing :exit_code, :stdout and :stderr
    def run(opts)
      dest = opts[:n].name
      cmd = opts[:c]

      ssh_channels = RSpec.configuration.ssh_channels
      puts "-----------------"
      puts "#{dest}$ #{cmd}"
      result = ssh_exec!(ssh_channels[dest], "cd /tmp && sudo sh -c #{shellescape(cmd)}")
      puts "-----------------"
      result
    end

    # Transfer files to a host in the NodeSet.
    #
    # @param opts [Hash] options
    # @return [Boolean] returns true if command succeeded, false otherwise
    # @todo This is damn ugly, because we ssh in as vagrant, we copy to a temp
    #   path then move it later. Its slow and brittle and we need a better
    #   solution. Its also very Linux-centrix in its use of temp dirs.
    def rcp(opts)
      #log.debug("[Vagrant@rcp] called with #{opts.inspect}")

      dest = opts[:d].name
      source = opts[:sp]
      dest_path = opts[:dp]

      # Grab a remote path for temp transfer
      tmpdest = tmppath

      # Do the copy and print out results for debugging
      cmd = "scp -r -F '#{ssh_config}' '#{source}' #{dest}:#{tmpdest}"
      puts "------------------"
      puts "localhost$ #{cmd}"
      r = systemu cmd

      result = {
        :exit_code => r[0].exitstatus,
        :stdout => r[1],
        :stderr => r[2]
      }

      print "#{result[:stdout]}"
      print "#{result[:stderr]}"
      puts "Exit code: #{result[:exit_code]}"

      # Now we move the file into their final destination
      result = run(:n => opts[:d], :c => "mv #{tmpdest} #{dest_path}")
      if result[:exit_code] == 0
        return true
      else
        return false
      end
    end

    # Create the Vagrantfile for the NodeSet.
    #
    # @api private
    def create_vagrantfile
      log.info "[Vagrant#create_vagrantfile] Creating vagrant file here: #{@vagrant_path}"
      FileUtils.mkdir_p(@vagrant_path)
      File.open(File.expand_path(File.join(@vagrant_path, "Vagrantfile")), 'w') do |f|
        f.write("Vagrant::Config.run do |c|\n")
        nodes.each do |k,v|
          log.debug "Filling in content for #{k}"

          ps = v.provider_specifics['vagrant']

          node_config = "  c.vm.define '#{k}' do |v|\n"
          node_config << "    v.vm.host_name = '#{k}'\n"
          node_config << "    v.vm.box = '#{ps['box']}'\n"
          node_config << "    v.vm.box_url = '#{ps['box_url']}'\n" unless ps['box_url'].nil?
          node_config << "    v.vm.base_mac = '#{randmac}'\n"
          node_config << "  end\n"

          f.write(node_config)
        end
        f.write("end\n")
      end
      log.debug "[Vagrant#create_vagrantfile] Finished creating vagrant file"
      nil
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
          result = systemu("vagrant ssh-config #{k} >> #{ssh_config_path}")
          puts result.inspect
        end
      end
      ssh_config_path
    end

    # Execute vagrant command in vagrant_path
    #
    # @api private
    # @param args [String] args to vagrant
    # @todo This seems a little too specific these days, might want to
    #   generalize. It doesn't use systemu, because we want to see the output
    #   immediately, but still - maybe we can make systemu do that.
    def vagrant(args)
      Dir.chdir(@vagrant_path) do
        system("vagrant #{args}")
      end
      nil
    end

  end
end
