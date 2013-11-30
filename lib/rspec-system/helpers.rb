require 'rspec-system/result'
require 'rspec-system/helpers/shell'
require 'rspec-system/helpers/rcp'

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
# * +node+ - queries and returns node information
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

  include RSpecSystem::Util

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
  # @overload shell(options)
  #   @param options [Hash] options for command execution
  #   @option options [String] :command command to execute. Mandatory.
  #   @option options [String] :c alias for :command
  #   @option options [String,RSpecSystem::Node] :node (defaults to what was defined
  #     default in your YAML file, otherwise if there is only one node it uses
  #     that) specifies node to execute command on.
  #   @option options [String,RSpecSystem::Node] :n alias for :node
  #   @option options [Fixnum] :timeout seconds of time to allow before timing
  #     out. Defaults to 0 (not timeout).
  # @overload shell(command)
  #   @param command [String] command to execute
  # @yield [result] yields result when called as a block
  # @yieldparam result [RSpecSystem::Helpers::Shell] result of run
  # @return [RSpecSystem::Helpers::Shell] result of run
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
    # If options is a string, turn the string into a command in the normal
    # options hash.
    if options.is_a?(String)
      options = {:c => options}
    end

    # sudo hook
    if RSpec.configuration.rs_use_sudo
      options[:c] = "sudo bash -l -c #{shellescape(options[:c])}" unless options[:c].start_with? "sudo"
    end

    RSpecSystem::Helpers::Shell.new(options, self, &block)
  end

  # Remotely copy files to a test host
  #
  # Just specify a source path, destination path, and optionally a destination
  # node (if the default isn't enough) and go.
  #
  # The underlying implementation is actually performed by the particular
  # node provider, however this abstraction should mean you shouldn't need
  # to worry about that.
  #
  # @param options [Hash] options for command execution
  # @option options [String] :source_path source to copy files from (currently
  #    only locally)
  # @option options [String] :sp alias for source_path
  # @option options [String] :destination_path destination for copy
  # @option options [String] :dp alias for dest_path
  # @option options [RSpecSystem::Node] :destination_node (default_node) destination node
  #   to transfer files to. Optional.
  # @option options [RSpecSystem::Node] :d alias for destination_node
  # @option options [RSpecSystem::Node] :source_node ('') Reserved
  #   for future use. Patches welcome.
  # @option options [RSpecSystem::Node] :s alias for source_node
  # @option options [Fixnum] :timeout seconds of time to allow before timing
  #   out. Defaults to 0 (no timeout).
  # @yield [result] yields result when called as a block
  # @yieldparam result [RSpecSystem::Helpers::Rcp] result of rcp
  # @return [RSpecSystem::Helpers::Rcp] result of rcp
  # @example Copying a path remotely
  #   describe 'test running' do
  #     it 'copy my files' do
  #       rcp :sp => 'mydata', :dp => '/srv/data'.should be_true
  #     end
  #   end
  def rcp(options, &block)
    # sudo hack
    if RSpec.configuration.rs_use_sudo
      orig_dest = options[:dp]
      tmp_dest = "/tmp/.rspec_system#{options[:dp].gsub(/\//, '_')}"
      options[:dp] = tmp_dest
      RSpecSystem::Helpers::Rcp.new(options, self, &block)
      options_ssh = {
        :n => options[:d],
        :c => "cp -r #{tmp_dest} #{orig_dest}" 
      }
      shell(options_ssh)
    else
      RSpecSystem::Helpers::Rcp.new(options, self, &block)
    end
  end

  # @!group Queries

  # Returns a particular node object from the current nodeset given a set of
  # criteria.
  #
  # If no options are supplied, it tries to return the default node.
  #
  # @param options [Hash] search criteria
  # @option options [String] :name the canonical name of the node
  # @return [RSpecSystem::Node] node object
  def node(options = {})
    ns = RSpecSystem::NodeSet.create
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
end
