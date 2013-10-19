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

    ENV_TYPE = 'vsphere'

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
        :node_sleep, :ssh_timeout, :ssh_tries, :ssh_sleep, :connect_timeout,
        :connect_tries]

      # Devise defaults, use fog configuration from file system if it exists
      defaults = load_fog_config()
      defaults = defaults.merge({
        :node_timeout => 1200,
        :node_tries => 10,
        :node_sleep => 30 + rand(60),
        :ssh_timeout => 60,
        :ssh_tries => 10,
        :ssh_sleep => 4,
        :connect_timeout => 60,
        :connect_tries => 10,
      })

      # Traverse the ENV variables and load them into our config automatically
      @vmconf = defaults
      ENV.each do |k,v|
        next unless k =~/^RSPEC_VSPHERE_/
        var = k.sub(/^RSPEC_VSPHERE_/, '').downcase.to_sym
        unless options.include?(var)
          log.info("Ignoring unknown environment variable #{k}")
          next
        end
        @vmconf[var] = v
      end

      # Initialize node storage if not already
      RSpec.configuration.rspec_storage[:nodes] ||= {}
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
    def with_connection(&block)
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

    # Setup the NodeSet by starting all nodes.
    #
    # @return [void]
    def setup
      with_connection do |dc|
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
        relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => rp)
        spec = RbVmomi::VIM.VirtualMachineCloneSpec(
          :location => relocateSpec,
          :powerOn => true,
          :template => false
        )

        log.info "Launching VSphere instances one by one"
        nodes.each do |k,v|
          #####################
          # Node launching step
          #####################
          RSpec.configuration.rspec_storage[:nodes][k] ||= {}

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
          RSpec.configuration.rspec_storage[:nodes][k][:vm] = vm_name

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
            RSpec.configuration.rspec_storage[:nodes][k][:ipaddress] = ipaddress
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

          #####################
          # SSH Step
          #####################
          tries = 0
          begin
            timeout(vmconf[:ssh_timeout]) do
              output << bold(color("localhost$", :green)) << " ssh #{k}\n"
              chan = Net::SSH.start(ipaddress, 'root', {
                :keys => vmconf[:ssh_keys].split(":"),
              })

              RSpec.configuration.rspec_storage[:nodes][k][:ssh] = chan
            end
          rescue Timeout::Error, SystemCallError => e
            tries += 1
            output << e.message << "\n"
            if tries < vmconf[:ssh_tries]
              log.info("Sleeping for #{vmconf[:ssh_sleep]} seconds then trying again ...")
              sleep vmconf[:ssh_sleep]
              retry
            else
              log.error("Inability to connect to host, already tried #{tries} times, throwing exception")
              raise e
            end
          end
          time3 = Time.now
          log.info "#{k}> Took #{time3 - start_time} seconds for instance to be ready"
        end
      end

      nil
    end

    # Shutdown the NodeSet by shutting down all nodes.
    #
    # @return [void]
    def teardown
      with_connection do |dc|
        nodes.each do |k,v|
          storage = RSpec.configuration.rspec_storage[:nodes][k]

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

    # Run a command on a host in the NodeSet.
    #
    # @param opts [Hash] options
    # @return [Hash] a hash containing :exit_code, :stdout and :stderr
    def run(opts)
      dest = opts[:n].name
      cmd = opts[:c]

      ssh = RSpec.configuration.rspec_storage[:nodes][dest][:ssh]
      ssh_exec!(ssh, cmd)
    end

    # Transfer files to a host in the NodeSet.
    #
    # @param opts [Hash] options
    # @return [Boolean] returns true if command succeeded, false otherwise
    # @todo This is damn ugly, because we ssh in as vagrant, we copy to a temp
    #   path then move it later. Its slow and brittle and we need a better
    #   solution. Its also very Linux-centrix in its use of temp dirs.
    def rcp(opts)
      dest = opts[:d].name
      source = opts[:sp]
      dest_path = opts[:dp]

      # Do the copy and print out results for debugging
      ssh = RSpec.configuration.rspec_storage[:nodes][dest][:ssh]

      begin
        ssh.scp.upload! source.to_s, dest_path.to_s, :recursive => true
      rescue => e
        log.error("Error with scp of file #{source} to #{dest}:#{dest_path}")
        raise e
      end

      true
    end

  end
end
