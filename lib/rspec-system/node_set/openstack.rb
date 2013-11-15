require 'net/ssh'
require 'net/scp'
require 'fog'
require 'rspec-system/node_set/base'

module RSpecSystem
  class NodeSet::Openstack < NodeSet::Base
    PROVIDER_TYPE = 'openstack'
    attr_accessor :vmconf

    CONFIG_KEYS = [
      :node_timeout,
      :username,
      :flavor_name,
      :image_name,
      :endpoint,
      :keypair_name,
      :network_name,
      :ssh_keys,
      :api_key
    ]

    def initialize(name, config, custom_prefabs_path, options)
      super
      @vmconf = read_config
      @now = Time.now.strftime '%Y%m%d-%H:%M:%S.%L'
      RSpec.configuration.rs_storage[:nodes] ||= {}
    end

    def launch
      nodes.each do |k,v|
        storage = RSpec.configuration.rs_storage[:nodes][k] ||= {}
        options = {
          :flavor_ref => flavor.id,
          :image_ref => image.id,
          :name => "#{k}-#{@now}",
          :key_name => vmconf[:keypair_name]
        }
        options[:nics] = [{'net_id' => nic.id}] if vmconf[:network_name]
        log.info "Launching openstack instance #{k}"
        result = compute.servers.create options
        storage[:server] = result
      end
    end

    def connect
      nodes.each do |k,v|
        server = RSpec.configuration.rs_storage[:nodes][k][:server]
        before = Time.new.to_i
        while true
          begin
            server.wait_for(5) { ready? }
            break
          rescue ::Fog::Errors::TimeoutError
            raise if Time.new.to_i - before > vmconf[:node_timeout]
            log.info "Timeout connecting to instance, trying again..."
          end
        end

        chan = ssh_connect(:host => k, :user => 'root', :net_ssh_options => {
          :keys => vmconf[:ssh_keys].split(':'),
          :host_name => server.addresses[vmconf[:network_name]].first['addr'],
          :paranoid => false
        })
        RSpec.configuration.rs_storage[:nodes][k][:ssh] = chan
      end
    end

    def teardown
      nodes.keys.each do |k|
        server = RSpec.configuration.rs_storage[:nodes][k][:server]
        log.info "Destroying server #{server.name}"
        server.destroy
      end
    end

    def compute
      @compute || @compute = Fog::Compute.new({
        :provider => :openstack,
        :openstack_username => vmconf[:username],
        :openstack_api_key => vmconf[:api_key],
        :openstack_auth_url => vmconf[:endpoint],
      })
    end

    def network
      @network || @network = Fog::Network.new({
        :provider => :openstack,
        :openstack_username => vmconf[:username],
        :openstack_api_key => vmconf[:api_key],
        :openstack_auth_url => vmconf[:endpoint],
      })
    end
    private

    def flavor
      log.info "Looking up flavor #{vmconf[:flavor_name]}"
      compute.flavors.find { |x| x.name == vmconf[:flavor_name] } || raise("Couldn't find flavor: #{vmconf[:flavor_name]}")
    end

    def image
      log.info "Looking up image #{vmconf[:image_name]}"
      compute.images.find { |x| x.name == vmconf[:image_name] } || raise("Couldn't find image: #{vmconf[:image_name]}")
    end

    def nic
      log.info "Looking up network #{vmconf[:network_name]}"
      network.networks.find { |x| x.name == vmconf[:network_name] } || raise("Couldn't find network: #{vmconf[:network_name]}")
    end

    def read_config
      conf = ENV.inject({}) do |memo,(k,v)|
        if k =~ /^RS_OPENSTACK_(.+)/
          var = $1.downcase.to_sym
          memo[var] = v if ([var] & CONFIG_KEYS).any?
        end
        memo
      end

      conf[:node_timeout] = conf[:node_timeout].to_i unless conf[:node_timeout].nil?
      conf
    end
  end
end
