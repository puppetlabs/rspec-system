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
  c.extend RSpecSystem::Helpers

  # Various global configuration items
  c.add_setting :rs_tmp,
    :default => Pathname.new(ENV['RS_TMP'] ||
                File.expand_path(File.join(File.basename(__FILE__), '..', '.rspec_system')))
  c.add_setting :rs_provider,
    :default => ENV['RS_PROVIDER'] ||
                ENV['RSPEC_VIRTUAL_ENV'] ||
                'vagrant_virtualbox'
  c.add_setting :rs_set,
    :default => ENV['RS_SET'] ||
                ENV['RSPEC_SET']
  c.add_setting :rs_destroy,
    :default => (ENV['RS_DESTROY'] || ENV['RSPEC_DESTROY']) =~ /(no|false)/ ? false : true
  c.add_setting :rs_custom_prefabs,
    :default => Pathname.new(ENV['RS_CUSTOM_PREFABS'] ||
                File.expand_path(File.join(File.basename(__FILE__), '..', '.prefabs.yml')))
  c.add_setting :rs_config,
    :default => YAML.load_file('.nodeset.yml')
  c.add_setting :rs_ssh_tries,
    :default => ENV['RS_SSH_TRIES'] || 10
  c.add_setting :rs_ssh_sleep,
    :default => ENV['RS_SSH_SLEEP'] || 4
  c.add_setting :rs_ssh_timeout,
    :default => ENV['RS_SSH_TIMEOUT'] || 60

  # Storage variable, for internal use only
  # @private
  c.add_setting :rs_storage, :default => {}

  ns = RSpecSystem::NodeSet.create
  c.before :suite do
    # Before Suite exceptions get captured it seems
    begin
      output << "=begin===========================================================\n"
      output << "\n"
      output << bold("Starting nodes") << "\n"
      output << "\n"
      output << bold("Setname:") << "             #{ns.setname}\n"
      output << bold("Configuration:") << "       #{ns.config.pretty_inspect}"
      output << bold("Virtual Environment:") << " #{ns.provider_type}\n"
      output << bold("Default node:") << "        #{ns.default_node.name}\n"
      output << bold("Destroy node:") << "        #{ns.destroy ? 'true' : 'false'}\n"
      output << "\n"
      ns.setup
      output << "\n"
      output << "=end=============================================================\n"
      output << "\n"
    rescue => ex
      output << ex.inspect + " in\n"
      output << ex.backtrace.join("\n  ") << "\n"
      exit(1)
    end
  end

  c.after :suite do
    # After Suite exceptions get captured it seems
    begin
      output << "\n"
      output << "=begin===========================================================\n"
      output << "\n"
      output << bold("Stopping nodes\n")
      output << "\n"
      ns.teardown
      output << "\n"
      output << "=end=============================================================\n"
    rescue => ex
      output << ex.inspect + " in\n"
      output << ex.backtrace.join("\n  ") << "\n"
    end
  end
end
