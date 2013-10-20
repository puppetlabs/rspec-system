require 'rspec-system/spec_helper'

# A localized module for storing project specific helpers
module LocalHelpers
  # Return the project root
  #
  # @return [Pathname] root directory of project
  def proj_root
    Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '..')))
  end

  # Return the fixture directory
  #
  # @return [Pathname] test fixture directory
  def fixture_root
    proj_root + 'spec' + 'fixtures'
  end
end

RSpec.configure do |c|
  c.include ::LocalHelpers

  c.before :suite do
    shell 'echo "mesg n" >> ~/.profile'
    shell 'echo foobar > /tmp/setupblock'
  end
end
