require 'rubygems'
require 'bundler/setup'

Bundler.require :default

require 'rspec/core/rake_task'
require 'rspec-system/rake_task'

begin
  require 'ci/reporter/rake/rspec'
rescue LoadError
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/unit/**/*_spec.rb"
end

task :default do
  sh %{rake -T}
end
