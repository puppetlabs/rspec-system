require 'fileutils'
require 'systemu'
require 'net/ssh'
require 'net/scp'
require 'rbvmomi'

module RSpecSystem
  # A NodeSet implementation for VSphere
  class NodeSet::Vsphere < RSpecSystem::NodeSet::Base
    include RSpecSystem::Log

    ENV_TYPE = 'vsphere'

    # Creates a new instance of RSpecSystem::NodeSet::Vsphere
    #
    # @param setname [String] name of the set to instantiate
    # @param config [Hash] nodeset configuration hash
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @param options [Hash] options Hash
    def initialize(setname, config, custom_prefabs_path, options)
      super
      @vim = RbVmomi::VIM.connect(
        :host => ENV["RSPEC_VSPHERE_HOST"],
        :user => ENV["RSPEC_VSPHERE_USER"],
        :password => ENV["RSPEC_VSPHERE_PASS"],
        :ssl => true,
        :insecure => true
      )

      # Initialize node storage if not already
      RSpec.configuration.rspec_storage[:nodes] ||= {}
    end

    # @!group NodeSet Methods

    # Setup the NodeSet by starting all nodes.
    #
    # @return [void]
    def setup
      log.info "[Vsphere#setup] Setup begins"

      dest_dir = ENV['RSPEC_VSPHERE_DEST_DIR']
      template_dir = ENV['RSPEC_VSPHERE_TEMPLATE_DIR']

      si = @vim.serviceInstance
      dc = si.find_datacenter

      rp = dc.find_compute_resource('general').resourcePool.find(ENV["RSPEC_VSPHERE_RPOOL"])
      relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => rp)
      spec = RbVmomi::VIM.VirtualMachineCloneSpec(
        :location => relocateSpec,
        :powerOn => true,
        :template => false
      )

      vm_folder = dc.vmFolder
      vm_newfolder = vm_folder.find(dest_dir)

      log.info "[Vsphere#setup] launching instances one by one"
      nodes.each do |k,v|
        ps = v.provider_specifics['vsphere']

        raise 'No provider specifics for this prefab' if ps.nil?

        template = ps['template']

        raise "No template specified for this prefab" if template.nil?

        log.info "[Vsphere#setup] launching instance #{k} with template #{template}"

        vm = vm_folder.find(ENV['RSPEC_VSPHERE_TEMPLATE_DIR']).find(template)

        raise "No template found" if vm.nil?

        vm_name = "rspec-system-#{k}-#{random_string(10)}"

        log.info "[Vsphere#setup] Cloning new vm #{vm_name} in folder #{dest_dir}"

        vm.CloneVM_Task(
          :folder => vm_newfolder,
          :name => vm_name,
          :spec => spec
        ).wait_for_completion

        log.info "[Vsphere#setup] Cloning complete"

        newvm = vm_newfolder.find(vm_name)
        guest_info = newvm.guest

        timeout(60) do
          while(newvm.guest.guestState != 'running') do
            sleep 2
            puts "#{k}> Waiting for vm to run ..."
          end
        end

        timeout(60) do
          while(newvm.guest.ipAddress == nil) do
            sleep 2
            puts "#{k}> Waiting for ip address ..."
          end
        end

        ipaddress = newvm.guest.ipAddress

        log.info "[Vsphere#setup] establishing Net::SSH channel with #{k}"
        chan = Net::SSH.start(ipaddress, 'vagrant', :password => 'vagrant')

        RSpec.configuration.rspec_storage[:nodes][k] = {
          :ipaddress => ipaddress,
          :ssh => chan,
          :vm => newvm
        }
        log.info "[Vsphere#setup] Node launched: #{k}"
      end

      log.info("[Vsphere#setup] setup complete")

      nil
    end

    # Shutdown the NodeSet by shutting down all nodes.
    #
    # @return [void]
    def teardown
      nodes.each do |k,v|
        storage = RSpec.configuration.rspec_storage[:nodes][k]

        if storage.nil?
          log.info "[Vsphere#teardown] No entry for node #{k}, no teardown necessary"
          next
        end

        log.info "[Vsphere#teardown] closing ssh channel to #{k}"
        ssh = storage[:ssh]
        ssh.close unless ssh.closed?

        if destroy
          log.info "[Vsphere#teardown] destroy instance #{k}"
          vm = storage[:vm]
          if vm == nil
            puts "No vm object"
            next
          end
          vm.PowerOffVM_Task.wait_for_completion
          vm.Destroy_Task.wait_for_completion
        else
          log.info "[Vsphere#teardown] Skipping destroy instance #{k}"
          next
        end
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

      ssh = RSpec.configuration.rspec_storage[:nodes][dest][:ssh]
      puts "-----------------"
      puts "#{dest}$ #{cmd}"
      result = ssh_exec!(ssh, "cd /tmp && sudo sh -c '#{cmd}'")
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
      ssh = RSpec.configuration.rspec_storage[:nodes][dest][:ssh]
      ssh.scp.upload! source.to_s, tmpdest.to_s, :recursive => true

      # Now we move the file into their final destination
      result = run(:n => opts[:d], :c => "mv #{tmpdest} #{dest_path}")
      if result[:exit_code] == 0
        return true
      else
        return false
      end
    end

  end
end
