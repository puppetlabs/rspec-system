require 'securerandom'

module RSpecSystem
  # A NodeSet implementation for lxc-docker
  class NodeSet::Docker < RSpecSystem::NodeSet::Base
    include RSpecSystem::Log
    include RSpecSystem::Util

    ENV_TYPE = 'docker'

    # Creates a new instance of RSpecSystem::NodeSet::Docker
    #
    # @param setname [String] name of the set to instantiate
    # @param config [Hash] nodeset configuration hash
    # @param custom_prefabs_path [String] path of custom prefabs yaml file
    # @param options [Hash] options Hash
    def initialize(setname, config, custom_prefab_path, options)
      super
    end

    # Launch nodes
    #
    # @return [void]
    def launch
      log.info "[Docker#launch] Begin setting up docker"

      docker_containers = nodes.inject({}) do |hash, (k,v)|
        ps = v.provider_specifics['docker']

        raise 'No provider specifics for this prefab' if ps.nil?

        image = ps['image']

        raise "No image specified for this prefab" if image.nil?

        if ! system("docker images | grep #{image} > /dev/null")
          system("docker pull #{image}")
        end

        image_name = "rspec-system-#{k}-#{SecureRandom.hex(10)}"

        log.info "[Docker#launch] building ssh-enabled image #{image_name} from image #{image}"
        IO.popen("docker build -t #{image_name} -", 'w') do |build|
          build.puts "FROM #{image}"
          build.puts "RUN #{install_ssh(v.facts['osfamily'])}"
          build.puts 'RUN mkdir /var/run/sshd'
          build.puts 'RUN echo \'rspec\nrspec\' | passwd root'
          build.puts "RUN echo '127.0.0.1 #{image_name}' >> /etc/hosts"
          build.puts 'EXPOSE 22'
          build.puts 'CMD /usr/sbin/sshd -D'
          build.close_write
        end

        log.info "[Docker#launch] launching container #{k} from built image #{image_name}"

        container = %x{docker run -d -h "#{image_name}" #{image_name}}.chomp

        hash[k] = {
          :id   => container,
          :name => image_name,
        }

        hash
      end
      RSpec.configuration.rs_storage[:nodes] = docker_containers
      nil
    end

    # Connect to the nodes
    #
    # @return [void]
    def connect
      nodes.each do |k,v|
        container = RSpec.configuration.rs_storage[:nodes][k][:id]
        port      = %x{docker port #{container} 22}.chomp
        ssh       = ssh_connect(:host => '127.0.0.1', :user => 'root', :net_ssh_options => {
          :password => 'rspec',
          :port     => port
        })

        RSpec.configuration.rs_storage[:nodes][k][:ssh] = ssh
      end

      nil
    end

    # Shutdown the NodeSet by shutting down all nodes.
    #
    # @return [void]
    def teardown
      log.info "[Docker#teardown] killing containers"
      RSpec.configuration.rs_storage[:nodes].each do |k,v|
        log.info "[Docker#teardown] stop ssh container #{k}"
        v[:ssh].close unless v[:ssh].closed?

        if destroy
          log.info "[Docker#teardown] kill container #{k} (#{v[:id]})"
          system("docker kill #{v[:id]}")
          system("docker rm #{v[:id]}")
          log.info "[Docker#teardown] rmi image #{k} (#{v[:name]})"
          system("docker rmi #{v[:name]}")
        else
          log.info "[Docker#teardown] Skipping kill container #{k} (#{v[:id]})"
          log.info "[Docker#teardown] Skipping rmi image #{k} (#{v[:name]})"
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

      ssh = RSpec.configuration.ssh_channels[dest][:ssh]
      puts "-----------------"
      puts "#{dest}$ #{cmd}"
      result = ssh_exec!(ssh, "cd /tmp && sudo sh -c #{shellescape(cmd)}")
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
      dest = opts[:d].name
      source = opts[:sp]
      dest_path = opts[:dp]

      # Grab a remote path for temp transfer
      tmpdest = tmppath

      # Do the copy and print out results for debugging
      ssh = RSpec.configuration.ssh_channels[dest][:ssh]
      ssh.scp.upload! source.to_s, tmpdest.to_s, :recursive => true

      # Now we move the file into their final destination
      result = run(:n => opts[:d], :c => "mv #{tmpdest} #{dest_path}")
      if result[:exit_code] == 0
        return true
      else
        return false
      end
    end

    # Install openssh to allow ssh
    #
    # @param osfamily [String] the OS family of node.
    # @return [void]
    # @api private
    def install_ssh(osfamily)
      case osfamily
      when /redhat/i
        'yum install openssh-server -y'
      when /debian/i
        'apt-get install openssh-server -y'
      end
    end
  end
end
