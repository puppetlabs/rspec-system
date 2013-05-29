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

    # Create new NodeSet, populating necessary data structures.
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
    def setup
      raise "Unimplemented method #setup"
    end

    # Shutdown the NodeSet by shutting down or pausing all nodes.
    def teardown
      raise "Unimplemented method #teardown"
    end

    # Run a command on a host in the NodeSet.
    def run(options)
      raise "Unimplemented method #run"
    end

    # Copy a file to the host in the NodeSet.
    def rcp(options)
      raise "Unimplemented method #rcp"
    end

    # Return environment type
    def env_type
      self.class::ENV_TYPE
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
            print d
            r[:stdout]+=d
          end

          channel.on_extended_data do |ch,type,data|
            d = data
            print d
            r[:stderr]+=d
          end

          channel.on_request("exit-status") do |ch,data|
            c = data.read_long
            puts "Exit code: #{c}"
            r[:exit_code] = c
          end

          channel.on_request("exit-signal") do |ch, data|
            s = data.read_string
            puts "Exit signal: #{s}"
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
