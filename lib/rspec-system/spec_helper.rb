# This file provides a require-able entry point for putting at the top of your
# tests, or in a shared helper.

require 'rspec-system'
require 'yaml'
require 'pp'
require 'tempfile'

include RSpecSystem::Helpers

RSpec.configure do |c|
  include RSpecSystem::Log
  c.include RSpecSystem::Helpers

  # This provides a path to save vagrant files
  c.add_setting :system_tmp
  # Block to execute for environment setup
  c.add_setting :system_setup_block
  # Storage for ssh channels
  c.add_setting :ssh_channels, :default => {}
  c.add_setting :rspec_storage, :default => {}

  def nodeset
    Pathname.new(File.join(File.basename(__FILE__), '..', '.nodeset.yml'))
  end

  def custom_prefabs_path
    File.expand_path(File.join(File.basename(__FILE__), '..', '.prefabs.yml'))
  end
  
  def rspec_system_tmp
    path = ENV["RSPEC_SYSTEM_TMP"] || File.expand_path(File.join(File.basename(__FILE__), '..', '.rspec_system'))
    FileUtils.mkdir_p(path)
    path
  end

  def rspec_system_config
    YAML.load_file('.nodeset.yml')
  end

  # Grab the type of virtual environment we wish to run these tests in
  def rspec_virtual_env
    ENV["RSPEC_VIRTUAL_ENV"] || 'vagrant'
  end

  # Defines if a set will be destroyed before and after tests
  def rspec_destroy
    return false if ENV["RSPEC_DESTROY"] =~ /(no|false)/
    return true
  end

  def rspec_system_node_set
    setname = ENV['RSPEC_SET'] || rspec_system_config['default_set']
    config = rspec_system_config['sets'][setname]
    options = {}
    options[:destroy] = rspec_destroy
    RSpecSystem::NodeSet.create(setname, config, rspec_virtual_env, custom_prefabs_path, options)
  end

  def start_nodes
    ns = rspec_system_node_set

    puts "Starting nodes"
    puts
    puts "Setname is: " + ns.setname
    puts "Configuration is: " + ns.config.pretty_inspect
    puts "Virtual Environment type is: #{ns.env_type}"
    puts "Default node is: #{ns.default_node.name}"
    puts "Destroy node is: #{ns.destroy}"
    puts

    ns.setup

    puts
    puts "Finished starting nodes"
    puts "================================================================="
  end

  def stop_nodes
    puts 'Stopping nodes'
    puts
    rspec_system_node_set.teardown
    puts 'Finished stopping nodes'
    puts "================================================================="
  end

  def call_custom_setup_block
    # Run test specific setup routines
    if pr = RSpec.configuration.system_setup_block then
      log.info "Running custom setup block"
      log.warn "The system_setup_block methodology will be deprecated in the next major release, use before :suite instead"
      pr.call
      log.info "Finished running custom setup block"
    end
  end

  # Default the system_tmp dir to something random
  c.system_tmp = rspec_system_tmp

  c.before :suite do
    # Before Suite exceptions get captured it seems
    begin
      start_nodes
      call_custom_setup_block
    rescue => ex
      puts ex.inspect + " in"
      puts ex.backtrace.join("\n  ")
      exit(1)
    end
  end

  c.after :suite do
    puts "================================================================="
    # After Suite exceptions get captured it seems
    begin
      stop_nodes
    rescue => ex
      puts ex.inspect + " in"
      puts ex.backtrace.join("\n  ")
    end
  end
end
