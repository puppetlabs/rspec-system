# Include this file to create the spec:* rake tasks

require 'rspec/core/rake_task'
require 'rspec-system/formatter'

RSpec::Core::RakeTask.new(:spec_system) do |c|
  c.pattern = "spec/system/**/*_spec.rb"
  c.rspec_opts = %w[--require rspec-system/formatter --format=RSpecSystem::Formatter]
end

namespace :spec do
  desc 'Run system tests'
  task :system => :spec_system
end
