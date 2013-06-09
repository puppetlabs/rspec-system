require 'rspec-system'

# This is a helper module that exposes some internal helpers used by the main
# public ones, also the startup and teardown routines.
#
# @api private
module RSpecSystem::InternalHelpers
  # Return the path to the nodeset file
  #
  # @return [Pathname]
  def nodeset
    Pathname.new(File.join(File.basename(__FILE__), '..', '.nodeset.yml'))
  end

  # Return the path to the custom prefabs file
  #
  # @return [Pathname]
  def custom_prefabs_path
    Pathname.new(File.expand_path(File.join(File.basename(__FILE__), '..', '.prefabs.yml')))
  end

  # Return the path to the temporary directory
  #
  # @return [Pathname]
  def rspec_system_tmp
    path = ENV["RSPEC_SYSTEM_TMP"] || File.expand_path(File.join(File.basename(__FILE__), '..', '.rspec_system'))
    FileUtils.mkdir_p(path)
    Pathname.new(path)
  end

  # Return the nodeset configuration hash
  #
  # @return [Hash] nodeset configuration
  def rspec_system_config
    YAML.load_file('.nodeset.yml')
  end

  # Grab the type of virtual environment we wish to run these tests in
  #
  # @return [String] current virtual env type
  def rspec_virtual_env
    ENV["RSPEC_VIRTUAL_ENV"] || 'vagrant'
  end

  # Defines if a set will be destroyed before and after tests
  #
  # @return [Boolean]
  def rspec_destroy
    return false if ENV["RSPEC_DESTROY"] =~ /(no|false)/
    return true
  end

  # Return the current nodeset object
  #
  # @return [RSpecSystem::NodeSet::Base] current nodeset object
  def rspec_system_node_set
    setname = ENV['RSPEC_SET'] || rspec_system_config['default_set']
    config = rspec_system_config['sets'][setname]
    options = {}
    options[:destroy] = rspec_destroy
    RSpecSystem::NodeSet.create(setname, config, rspec_virtual_env, custom_prefabs_path, options)
  end

  # Start all nodes
  #
  # @return [void]
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
    nil
  end

  # Stop all nodes
  #
  # @return [void]
  def stop_nodes
    puts 'Stopping nodes'
    puts
    rspec_system_node_set.teardown
    puts 'Finished stopping nodes'
    puts "================================================================="
    nil
  end
end
