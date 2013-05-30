require 'rspec-system/spec_helper'

module LocalHelpers
  def proj_root
    Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '..')))
  end

  def fixture_root
    proj_root + 'spec' + 'fixtures'
  end
end

RSpec.configure do |c|
  c.include ::LocalHelpers

  c.before :suite do
    shell 'echo foobar > /tmp/setupblock'
  end

  # NOTE: this is deprecated, but we do this for legacy testing purposes
  # with the next major release we should remove this capability, and remove
  # the test. Do not use this in your own tests any more!
  c.system_setup_block = proc do
    shell 'echo foobar > /tmp/setupblockold'
  end
end
