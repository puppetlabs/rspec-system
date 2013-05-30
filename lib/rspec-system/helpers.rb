require 'rspec-system/result'

# This module contains the main rspec helpers that are to be used within
# rspec-system tests. These are the meat-and-potatoes of your system tests,
# and in theory there shouldn't be anything you can't do without the helpers
# here.
#
# These helpers in particular are core to the framework. You can however
# combine these helpers to create your own more powerful helpers in rspec
# if you wish.
#
# The helpers themselves are split into two main groups, Queries:
#
# * +system_node+ - queries and returns node information
#
# And Actions:
#
# * +shell+ - runs a command on a node
# * +rcp+ - remote copies to a node
#
# @example Using node in your tests
#   describe 'test running' do
#     it 'do something if redhat' do
#       if node.facts['operatingsystem'] == 'RedHat' do
#         shell 'cat /etc/redhat-release'
#       end
#     end
#   end
# @example Make your own helper
#   describe 'my own helper' do
#     def install_puppet
#       facts = node.facts
#
#       # Grab PL repository and install PL copy of puppet
#       if facts['osfamily'] == 'RedHat'
#         shell 'rpm -ivh http://yum.puppetlabs.com/el/5/products/i386/puppetlabs-release-5-6.noarch.rpm'
#         shell 'yum install -y puppet'
#       elsif facts['osfamily'] == 'Debian'
#         shell "wget http://apt.puppetlabs.com/puppetlabs-release-#{facts['lsbdistcodename']}.deb"
#         shell "dpkg -i puppetlabs-release-#{facts['lsbdistcodename']}.deb"
#         shell 'apt-get update'
#         shell 'apt-get install -y puppet'
#       end
#     end
#
#     it 'test installing latest puppet' do
#       install_puppet
#       shell 'puppet apply --version' do |r|
#         r.exit_code.should be_zero
#         r.stdout.should =~ /3.1/
#         r.stderr.should be_empty
#       end
#     end
#   end
module RSpecSystem::Helpers
  # @!group Actions

  # @!macro shell_method
  #   @api public
  #   @overload $0(options)
  #     @param options [Hash] options for command execution
  #     @option options [String] :command command to execute. Mandatory.
  #     @option options [String] :c alias for :command
  #     @option options [RSpecSystem::Node] :node (defaults to what was defined
  #       default in your YAML file, otherwise if there is only one node it uses
  #       that) specifies node to execute command on.
  #     @option options [RSpecSystem::Node] :n alias for :node
  #   @overload $0(command)
  #     @param command [String] command to execute
  #   @yield [result] yields result when called as a block
  #   @yieldparam result [RSpecSystem::Result] result of run containing
  #     :exit_code, :stdout and :stderr
  #   @return [RSpecSystem::Result] result of run containing :exit_code,
  #     :stdout and :stderr

  # Runs a shell command on a test host.
  #
  # When invoked as a block a result hash is yielded to the block as a
  # parameter. Alternatively the result hash it is returned to the caller.
  #
  # If you have only provided 1 node in your nodeset, or you have specified a
  # a default you can avoid entering the name of the node if you wish. The
  # method for simplicity can accept a string instead of an options hash
  # and it knows to default everything else.
  #
  # The underlying implementation is actually performed by the particular
  # node provider, however this abstraction should mean you shouldn't need
  # to worry about that.
  #
  # @api public
  # @macro shell_method
  # @example Using it as a helper
  #   it 'test a command' do
  #     shell 'cat /etc/hosts' do |r|
  #       # Test stdout contains 'localhost'
  #       r.stdout.should =~ /localhost/
  #       # Test stderr is empty
  #       r.stderr.should == ''
  #       # Test exit_code is 0
  #       r.exit_code.should == 0
  #     end
  #   end
  # @example Running arbitrary commands
  #   it 'run some commands' do
  #     # Run a command without testing results
  #     shell 'echo "foobar" > /tmp/foo'
  #
  #     # Now we try to cat the file, and make sure it worked
  #     shell 'cat /tmp/foo' do |r|
  #       r.stdout.should =~ /foobar/
  #     end
  #   end
  def shell(options, &block)
    ns = rspec_system_node_set
    dn = ns.default_node

    # If options is a string, turn the string into a command in the normal
    # options hash.
    if options.is_a?(String)
      options = {:c => options}
    end

    # Defaults etc.
    options = {
      :node => options[:n] || dn,
      :n => options[:node] || dn,
      :c => options[:command],
      :command => options[:c],
    }.merge(options)

    if options[:c].nil?
      raise "Cannot use shell with no :command option"
    end

    result = RSpecSystem::Result.new(ns.run(options))

    if block_given?
      yield(result)
    else
      result
    end
  end

  # Legacy method for running a shell command.
  #
  # @deprecated Use {#shell} instead
  # @macro shell_method
  def system_run(options, &block)
    log.warn('system_run is deprecated, use shell instead')

    shell(options, &block)
  end

  # @!macro rcp_method
  #   @param options [Hash] options for command execution
  #   @option options [String] :source_path source to copy files from (currently
  #      only locally)
  #   @option options [String] :sp alias for source_path
  #   @option options [String] :destination_path destination for copy
  #   @option options [String] :dp alias for dest_path
  #   @option options [RSpecSystem::Node] :destination_node (default_node) destination node
  #     to transfer files to. Optional.
  #   @option options [RSpecSystem::Node] :d alias for destination_node
  #   @option options [RSpecSystem::Node] :source_node ('') Reserved
  #     for future use. Patches welcome.
  #   @option options [RSpecSystem::Node] :s alias for source_node
  #   @return [Bool] returns true if successful

  # Remotely copy files to a test host
  #
  # Just specify a source path, destination path, and optionally a destination
  # node (if the default isn't enough) and go.
  #
  # The underlying implementation is actually performed by the particular
  # node provider, however this abstraction should mean you shouldn't need
  # to worry about that.
  #
  # @macro rcp_method
  # @example Copying a path remotely
  #   describe 'test running' do
  #     it 'copy my files' do
  #       rcp :sp => 'mydata', :dp => '/srv/data'.should be_true
  #     end
  #   end
  def rcp(options)
    ns = rspec_system_node_set
    options = {
      :source_path => options[:sp],
      :destination_path => options[:dp],
      :dp => options[:destination_path],
      :sp => options[:source_path],
      :destination_node => ns.default_node,
      :d => ns.default_node,
      :source_node => nil,
      :s => nil,
    }.merge(options)

    d = options[:d]
    sp = options[:sp]
    dp = options[:dp]

    log.info("rcp from #{sp} to #{d.name}:#{dp} executed")
    ns.rcp(options)
  end

  # Legacy method for copying a file to a test host
  #
  # @deprecated Use {#rcp} instead
  # @macro rcp_method
  def system_rcp(options)
    log.warn('system_rcp is deprecated, use rcp instead')
    rcp(options)
  end

  # @!group Queries

  # @!macro node_method
  #   @param options [Hash] search criteria
  #   @option options [String] :name the canonical name of the node
  #   @return [RSpecSystem::Node] node object

  # Returns a particular node object from the current nodeset given a set of
  # criteria.
  #
  # If no options are supplied, it tries to return the default node.
  #
  # @macro node_method
  def node(options = {})
    ns = rspec_system_node_set
    options = {
      :name => ns.default_node.name,
    }.merge(options)

    name = options[:name]

    if name.nil?
      raise "No nodes search specified, and no default"
    else
      return ns.nodes[name]
    end
  end

  # Legacy method for querying nodes
  #
  # @deprecated Use {#node} instead
  # @macro node_method
  def system_node(options = {})
    log.warn('system_node is deprecated, use node instead')
    node(options)
  end
end
