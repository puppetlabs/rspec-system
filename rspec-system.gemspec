# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  # Metadata
  s.name        = "rspec-system"
  s.version     = "2.8.0"
  s.authors     = ["Ken Barber"]
  s.email       = ["info@puppetlabs.com"]
  s.homepage    = "https://github.com/puppetlabs/rspec-system"
  s.summary     = "System testing with rspec"
  s.license     = "Apache 2.0"

  # Manifest
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*_spec.rb`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib", "resources"]

  # Dependencies
  s.required_ruby_version = '>= 1.8.7'
  s.add_runtime_dependency "rspec", '~>2.14'
  s.add_runtime_dependency "kwalify", '~>0.7.2'
  s.add_runtime_dependency "systemu", '~>2.5'
  s.add_runtime_dependency "net-ssh", '~>2.7'
  s.add_runtime_dependency "net-scp", '~>1.1'
  s.add_runtime_dependency "rbvmomi", '~>1.6'
  # It seems 1.6.0 relies on ruby 1.9.2, so lets pin it for now
  s.add_runtime_dependency "nokogiri", '~>1.5.10'
  s.add_runtime_dependency 'fog', '~> 1.18'
  # 2.0 drops 1.8.7 support
  s.add_runtime_dependency 'mime-types', '~> 1.16'

end
