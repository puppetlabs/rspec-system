# This file provides a require-able entry point for putting at the top of your
# tests, or in a shared helper.

require 'rspec-system'
require 'yaml'
require 'pp'
require 'tempfile'

RSpec.configure do |c|
  include RSpecSystem::Log
  c.include RSpecSystem::Helpers

  # This provides a path to save vagrant files
  c.add_setting :system_tmp
  # Block to execute for environment setup
  c.add_setting :system_setup_block
  # Storage for ssh channels
  c.add_setting :ssh_channels, :default => {}

  def nodeset
    Pathname.new(File.join(File.basename(__FILE__), '..', '.nodeset.yml'))
  end

  def rspec_system_config
    YAML.load_file('.nodeset.yml')
  end

  # Grab the type of virtual environment we wish to run these tests in
  def rspec_virtual_env
    ENV["RSPEC_VIRTUAL_ENV"] || 'vagrant'
  end

  def rspec_system_node_set
    setname = ENV['RSPEC_SET'] || rspec_system_config['default_set']
    config = rspec_system_config['sets'][setname]
    RSpecSystem::NodeSet.create(setname, config, rspec_virtual_env)
  end

  def start_nodes
    ns = rspec_system_node_set

    log.info "START RSPEC-SYSTEM SETUP"
    log.info "Setname is: " + ns.setname
    log.info "Configuration is: " + ns.config.pretty_inspect
    log.info "Virtual Environment type is: #{ns.env_type}"
    log.info "Default node is: #{ns.default_node.name}"

    ns.setup
  end

  def stop_nodes
    log.info 'FINALIZE RSPEC-SYSTEM SETUP'
    rspec_system_node_set.teardown
  end

  def call_custom_setup_block
    # Run test specific setup routines
    if pr = RSpec.configuration.system_setup_block then
      log.info "Running custom setup block"
      pr.call
      log.info "Finished running custom setup block"
    end
  end

  # Default the system_tmp dir to something random
  c.system_tmp = Dir.mktmpdir

  c.before :suite do
    start_nodes
    call_custom_setup_block
  end

  c.after :suite do
    stop_nodes
  end
end
