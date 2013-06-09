# This file provides a require-able entry point for putting at the top of your
# tests, or in a shared helper.

require 'rspec-system'
require 'yaml'
require 'pp'
require 'tempfile'

include RSpecSystem::Helpers

RSpec.configure do |c|
  include RSpecSystem::Log
  include RSpecSystem::InternalHelpers
  c.include RSpecSystem::Helpers
  c.include RSpecSystem::InternalHelpers
  c.extend RSpecSystem::Helpers

  # This provides a path to save vagrant files
  c.add_setting :system_tmp
  # Storage for ssh channels
  c.add_setting :ssh_channels, :default => {}
  c.add_setting :rspec_storage, :default => {}

  # Default the system_tmp dir to something random
  c.system_tmp = rspec_system_tmp

  c.before :suite do
    # Before Suite exceptions get captured it seems
    begin
      start_nodes
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
