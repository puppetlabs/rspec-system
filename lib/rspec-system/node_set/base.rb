module RSpecSystem
  # Base class for a NodeSet driver. If you want to create a new driver, you
  # should sub-class this and override all the methods below.
  #
  # @abstract Subclass and override methods to create a new NodeSet variant.
  class NodeSet::Base
    attr_reader :config
    attr_reader :setname
    attr_reader :custom_prefabs_path
    attr_reader :nodes
    attr_reader :destroy

    # @!group Abstract Methods

    # Create new NodeSet, populating necessary data structures.
    #
    # @abstract override for providing global storage and setup-level code
    def initialize(setname, config, custom_prefabs_path, options)
      @setname = setname
      @config = config
      @custom_prefabs_path = custom_prefabs_path
      @destroy = options[:destroy]

      @nodes = {}
      config['nodes'].each do |k,v|
        @nodes[k] = RSpecSystem::Node.node_from_yaml(self, k, v, custom_prefabs_path)
      end
    end

    # Setup the NodeSet by starting all nodes.
    #
    # @return [void]
    def setup
      launch
      connect
      configure
    end

    # Launch nodes
    #
    # @return [void]
    # @abstract Override this method and provide your own launch code
    def launch
      raise RuntimeError "Unimplemented method #launch"
    end

    # Connect nodes
    #
    # @return [void]
    # @abstract Override this method and provide your own connect code
    def connect
      raise RuntimeError "Unimplemented method #connect"
    end

    # Configure nodes
    #
    # This is the global configure method that sets up a node before tests are
    # run, making sure any important preparation steps are executed.
    #
    # * fixup profile to stop using mesg to avoid extraneous noise
    # * ntp synchronisation
    # * hostname & hosts setup
    #
    # @return [void]
    # @abstract Override this method and provide your own configure code
    def configure
      nodes.each do |k,v|
        rs_storage = RSpec.configuration.rs_storage[:nodes][k]

        # Fixup profile to avoid noise
        if v.facts['osfamily'] == 'Debian'
          shell(:n => k, :c => "sed -i 's/^mesg n/# mesg n/' /root/.profile")
        end

        # Setup ntp
        if v.facts['osfamily'] == 'Debian' then
          shell(:n => k, :c => 'apt-get install -y ntpdate')
        elsif v.facts['osfamily'] == 'RedHat' then
          if v.facts['lsbmajdistrelease'] == '5' then
            shell(:n => k, :c => 'yum install -y ntp')
          else
            shell(:n => k, :c => 'yum install -y ntpdate')
          end
        end
        shell(:n => k, :c => 'ntpdate -u pool.ntp.org')

        # Grab IP address for host, if we don't already have one
        rs_storage[:ipaddress] ||= shell(:n => k, :c => "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1").stdout.chomp

        # Configure local hostname and hosts file
        shell(:n => k, :c => "hostname #{k}")

        if v.facts['osfamily'] == 'Debian' then
          shell(:n => k, :c => "echo '#{k}' > /etc/hostname")
        end

        hosts = <<-EOS
#{rs_storage[:ipaddress]} #{k}
127.0.0.1 #{k} localhost
::1 #{k} localhost
        EOS
        shell(:n => k, :c => "echo '#{hosts}' > /etc/hosts")

        # Display setup for diagnostics
        shell(:n => k, :c => 'cat /etc/hosts')
        shell(:n => k, :c => 'hostname')
        shell(:n => k, :c => 'hostname -f')
      end
      nil
    end

    # Shutdown the NodeSet by shutting down or pausing all nodes.
    #
    # @return [void]
    # @abstract Override this method and provide your own node teardown code
    def teardown
      raise RuntimeError "Unimplemented method #teardown"
    end

    # Run a command on a host in the NodeSet.
    #
    # @param opts [Hash] options hash containing :n (node) and :c (command)
    # @return [Hash] a hash containing :stderr, :stdout and :exit_code
    # @abstract Override this method providing your own shell running code
    def run(opts)
      dest = opts[:n].name
      cmd = opts[:c]

      ssh = RSpec.configuration.rs_storage[:nodes][dest][:ssh]
      ssh_exec!(ssh, cmd)
    end

    # Copy a file to the host in the NodeSet.
    #
    # @param opts [Hash] options
    # @option opts [RSpecHelper::Node] :d destination node
    # @option opts [String] :sp source path
    # @option opts [String] :dp destination path
    # @return [Boolean] returns true if command succeeded, false otherwise
    # @abstract Override this method providing your own file transfer code
    def rcp(opts)
      dest = opts[:d].name
      source = opts[:sp]
      dest_path = opts[:dp]

      # Do the copy and print out results for debugging
      ssh = RSpec.configuration.rs_storage[:nodes][dest][:ssh]

      begin
        ssh.scp.upload! source.to_s, dest_path.to_s, :recursive => true
      rescue => e
        log.error("Error with scp of file #{source} to #{dest}:#{dest_path}")
        raise e
      end

      true
    end

    # @!group Common Methods

    # Return environment type
    def provider_type
      self.class::PROVIDER_TYPE
    end

    # Return default node
    #
    # @return [RSpecSystem::Node] default node for this nodeset
    def default_node
      dn = config['default_node']
      if dn.nil?
        if nodes.length == 1
          dn = nodes.first[1]
          return dn
        else
          raise "No default node"
        end
      else
        return nodes[dn]
      end
    end

    # Return a random string of chars, used for temp dir creation
    #
    # @return [String] string of 50 random characters A-Z and a-z
    def random_string(length = 50)
      o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
      (0...length).map{ o[rand(o.length)] }.join
    end

    # Generates a random string for use in remote transfers.
    #
    # @return [String] a random path
    # @todo Very Linux dependant, probably need to consider OS X and Windows at
    #   least.
    def tmppath
      '/tmp/' + random_string
    end

    # Connect via SSH in a resilient way
    #
    # @param [Hash] opts
    # @option opts [String] :host Host to connect to
    # @option opts [String] :user User to connect as
    # @option opts [Hash] :net_ssh_options Options hash as used by `Net::SSH.start`
    # @return [Net::SSH::Connection::Session]
    # @api protected
    def ssh_connect(opts = {})
      ssh_sleep = RSpec.configuration.rs_ssh_sleep
      ssh_tries = RSpec.configuration.rs_ssh_tries
      ssh_timeout = RSpec.configuration.rs_ssh_timeout

      tries = 0
      begin
        timeout(ssh_timeout) do
          output << bold(color("localhost$", :green)) << " ssh -l #{opts[:user]} #{opts[:host]}\n"
          Net::SSH.start(opts[:host], opts[:user], opts[:net_ssh_options])
        end
      rescue Timeout::Error, SystemCallError, Net::SSH::Exception => e
        tries += 1
        output << e.message << "\n"
        if tries < ssh_tries
          log.info("Sleeping for #{ssh_sleep} seconds then trying again ...")
          sleep ssh_sleep
          retry
        else
          log.error("Inability to connect to host, already tried #{tries} times, throwing exception")
          raise e
        end
      end
    end

    # Execute command via SSH.
    #
    # A special version of exec! from Net::SSH that returns exit code and exit
    # signal as well. This method is blocking.
    #
    # @param ssh [Net::SSH::Connection::Session] an active ssh session
    # @param command [String] command to execute
    # @return [Hash] a hash of results
    def ssh_exec!(ssh, command)
      r = {
        :stdout => '',
        :stderr => '',
        :exit_code => nil,
        :exit_signal => nil,
      }
      ssh.open_channel do |channel|
        channel.exec(command) do |ch, success|
          unless success
            abort "FAILED: couldn't execute command (ssh.channel.exec)"
          end
          channel.on_data do |ch,data|
            d = data
            output << d
            r[:stdout]+=d
          end

          channel.on_extended_data do |ch,type,data|
            d = data
            output << d
            r[:stderr]+=d
          end

          channel.on_request("exit-status") do |ch,data|
            c = data.read_long
            output << bold("Exit code:") << " #{c}\n"
            r[:exit_code] = c
          end

          channel.on_request("exit-signal") do |ch, data|
            s = data.read_string
            output << bold("Exit signal:") << " #{s}\n"
            r[:exit_signal] = s
          end
        end
      end
      ssh.loop

      r
    end

    # Return a random mac address
    #
    # @return [String] a random mac address
    def randmac
      "080027" + (1..3).map{"%0.2X"%rand(256)}.join
    end
  end
end
