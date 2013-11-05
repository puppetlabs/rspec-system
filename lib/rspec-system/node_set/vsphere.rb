require 'fileutils'
require 'systemu'
require 'net/ssh'
require 'net/scp'
require 'rbvmomi'
require 'rspec-system/node_set/base'

module RSpecSystem
  # A NodeSet implementation for VSphere
  class NodeSet::Vsphere < RSpecSystem::NodeSet::Base
    include RSpecSystem::Log

    PROVIDER_TYPE = 'vsphere'

    attr_reader :vmconf

    # Creates a new instance of RSpecSystem::NodeSet::Vsphere
    #
    # @param setname [String] name of the set to instantiate
    # @param config [Hash] nodeset configuration hash
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @param options [Hash] options Hash
    def initialize(setname, config, custom_prefabs_path, options)
      super

      # Valid supported ENV variables
      options = [:host, :user, :pass, :dest_dir, :template_dir, :rpool,
        :cluster, :ssh_keys, :datacenter, :node_timeout, :node_tries,
        :node_sleep, :connect_timeout, :connect_tries]

      # Devise defaults, use fog configuration from file system if it exists
      defaults = load_fog_config()
      defaults = defaults.merge({
        :node_timeout => 1200,
        :node_tries => 10,
        :node_sleep => 30 + rand(60),
        :connect_timeout => 60,
        :connect_tries => 10,
      })

      # Traverse the ENV variables and load them into our config automatically
      @vmconf = defaults
      ENV.each do |k,v|
        next unless k =~/^RS(PEC)?_VSPHERE_/
        var = k.sub(/^RS(PEC)?_VSPHERE_/, '').downcase.to_sym
        unless options.include?(var)
          log.info("Ignoring unknown environment variable #{k}")
          next
        end
        @vmconf[var] = v
      end

      # Initialize node storage if not already
      RSpec.configuration.rs_storage[:nodes] ||= {}
    end

    # Retrieves fog configuration if it exists
    #
    # @api private
    def load_fog_config(path = ENV['HOME'] + '/.fog')
      creds = {}
      if File.exists?(path)
        fog = YAML.load_file(path)
        fog[:default] ||= {}
        creds = {
          :host => fog[:default][:vsphere_server],
          :user => fog[:default][:vsphere_username],
          :pass => fog[:default][:vsphere_password],
        }
      end

      return creds
    end

    # This is a DSL based wrapper that provides connection and disconnection
    # handling for the VSphere client API.
    #
    # The connection handling automatically retries upon failure.
    #
    # @api private
    def with_vsphere_connection(&block)
      vim = nil
      dc = nil

      tries = 0
      begin
        timeout(vmconf[:connect_timeout]) do
          vim = RbVmomi::VIM.connect(
            :host => vmconf[:host],
            :user => vmconf[:user],
            :password => vmconf[:pass],
            :ssl => true,
            :insecure => true
          )
        end
      rescue => e
        tries += 1
        log.error("Failure to connect (attempt #{tries})")
        if tries < vmconf[:connect_tries]
          log.info("Retry connection")
          retry
        end
        log.info("Failed to connect after #{tries} attempts, throwing exception")
        raise e
      end

      begin
        dc = vim.serviceInstance.find_datacenter(vmconf[:datacenter])
      rescue => e
        log.error("Unable to retrieve datacenter #{vmconf[:datacenter]}")
        raise e
      end

      block.call(dc)

      vim.close
    end

    # @!group NodeSet Methods

    # Launch the nodes
    #
    # @return [void]
    def launch
      with_vsphere_connection do |dc|
        # Traverse folders to find target folder for new vm's and template
        # folders. Automatically create the destination folder if it doesn't
        # exist.
        dest_folder = dc.vmFolder.traverse!(vmconf[:dest_dir], RbVmomi::VIM::Folder)
        raise "Destination folder #{vmconf[:dest_dir]} not found" if dest_folder.nil?
        template_folder = dc.vmFolder.traverse(vmconf[:template_dir], RbVmomi::VIM::Folder)
        raise "Template folder #{vmconf[:template_dir]} not found" if template_folder.nil?

        # Find resource pool and prepare clone spec for cloning further down.
        rp = dc.find_compute_resource(vmconf[:cluster]).
                resourcePool.
                traverse(vmconf[:rpool])
        relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(
          :diskMoveType => :moveChildMostDiskBacking,
          :pool => rp
        )
        spec = RbVmomi::VIM.VirtualMachineCloneSpec(
          :location => relocateSpec,
          :powerOn => true,
          :template => false
        )

        log.info "Launching VSphere instances one by one"
        nodes.each do |k,v|
          RSpec.configuration.rs_storage[:nodes][k] ||= {}

          # Obtain the template name to use
          ps = v.provider_specifics['vsphere']
          raise 'No provider specifics for this prefab' if ps.nil?
          template = ps['template']
          raise "No template specified for this prefab" if template.nil?

          # Traverse to find template VM object
          vm = template_folder.find(template, RbVmomi::VIM::VirtualMachine)
          raise "Cannot template find template #{template} in folder #{vmconf[:template_dir]}" if vm.nil?

          # Create a random name for the new VM
          vm_name = "rspec-system-#{k}-#{random_string(10)}"
          RSpec.configuration.rs_storage[:nodes][k][:vm] = vm_name

          log.info "Launching VSphere instance #{k} with template #{vmconf[:template_dir]}/#{template} as #{vmconf[:dest_dir]}/#{vm_name}"

          ipaddress = nil
          newvm = nil
          tries = 0
          start_time = Time.now
          begin
            timeout(vmconf[:node_timeout]) do
              log.info "Cloning new VSphere vm #{vm_name} in folder #{vmconf[:dest_dir]}"
              vm.CloneVM_Task(
                :folder => dest_folder,
                :name => vm_name,
                :spec => spec
              ).wait_for_completion
              time1 = Time.now
              log.info "Cloning complete, took #{time1 - start_time} seconds"

              newvm = dest_folder.find(vm_name, RbVmomi::VIM::VirtualMachine)
              raise "Cannot find newly built virtual machine #{vm_name} in folder #{vmconf[:dest_dir]}" if newvm.nil?

              while(newvm.guest.guestState != 'running') do
                sleep 4
                log.info "#{k}> Waiting for vm to run ..."
              end
              time2 = Time.now
              log.info "#{k}> Time in seconds for VM to run: #{time2 - time1}"

              while((ipaddress = newvm.guest.ipAddress) == nil) do
                sleep 4
                log.info "#{k}> Waiting for ip address ..."
              end
              time3 = Time.now
              log.info "#{k}> Time in seconds waiting for IP: #{time3 - time2}"
            end
            RSpec.configuration.rs_storage[:nodes][k][:ipaddress] = ipaddress
          rescue Timeout::Error, SystemCallError => e
            tries += 1
            log.error("VM launch attempt #{tries} failed with: " + e.message)
            if tries < vmconf[:node_tries]
              log.info("Destroying any VM's, sleeping then trying again ...")
              begin
                newvm.PowerOffVM_Task.wait_for_completion
              rescue RbVmomi::Fault => e
                log.error "Fault attempting to power off node #{k}, #{e.message}"
              ensure
                begin
                  newvm.Destroy_Task.wait_for_completion
                rescue RbVmomi::Fault => e
                  log.error "Fault attempting to destroy node #{k}, #{e.message}"
                end
              end
              sleep_time = vmconf[:node_sleep]
              log.info("Sleeping #{sleep_time} seconds before trying again ...")
              sleep sleep_time
              retry
            else
              log.error("Failed to create VM and already retried #{tries} times, throwing exception")
              raise e
            end
          end

          time2 = Time.now
          log.info "#{k}> Took #{time2 - start_time} seconds to boot instance"
        end
      end

      nil
    end

    # Connect to the nodes
    #
    # @return [void]
    def connect
      nodes.each do |k,v|
        rs_storage = RSpec.configuration.rs_storage[:nodes][k]
        raise RuntimeError, "No internal storage for node #{k}" if rs_storage.nil?

        ipaddress = rs_storage[:ipaddress]
        raise RuntimeError, "No ipaddress provided from launch phase for node #{k}" if ipaddress.nil?

        chan = ssh_connect(:host => k, :user => 'root', :net_ssh_options => {
          :keys => vmconf[:ssh_keys].split(":"),
          :host_name => ipaddress,
        })
        RSpec.configuration.rs_storage[:nodes][k][:ssh] = chan
      end

      nil
    end

    # Shutdown the NodeSet by shutting down all nodes.
    #
    # @return [void]
    def teardown
      with_vsphere_connection do |dc|
        nodes.each do |k,v|
          storage = RSpec.configuration.rs_storage[:nodes][k]

          if storage.nil?
            log.info "No entry for node #{k}, no teardown necessary"
            next
          end

          ssh = storage[:ssh]
          unless ssh.nil? or ssh.closed?
            ssh.close
          end

          if destroy
            log.info "Destroying instance #{k}"
            vm_name = storage[:vm]
            if vm_name == nil
              log.error "No vm object for #{k}"
              next
            end

            # Traverse folders to find target folder for new vm's
            vm_folder = dc.vmFolder.traverse(vmconf[:dest_dir], RbVmomi::VIM::Folder)
            raise "VirtualMachine folder #{vmconf[:dest_dir]} not found" if vm_folder.nil?
            vm = vm_folder.find(vm_name, RbVmomi::VIM::VirtualMachine)
            raise "VirtualMachine #{vm_name} not found in #{vmconf[:dest_dir]}" if vm.nil?

            begin
              vm.PowerOffVM_Task.wait_for_completion
            rescue RbVmomi::Fault => e
              log.error "Fault attempting to power off node #{k}, #{e.message}"
            ensure
              begin
                vm.Destroy_Task.wait_for_completion
              rescue RbVmomi::Fault => e
                log.error "Fault attempting to destroy node #{k}, #{e.message}"
              end
            end
          else
            next
          end
        end
      end

      nil
    end

  end
end
