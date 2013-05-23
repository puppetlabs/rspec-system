require 'spec_helper'
require 'rspec-system/util'

describe RSpecSystem::Util do
  let(:cls) do
    cls = Object.new
    cls.extend(RSpecSystem::Util)
  end

  describe '#shellescape' do
    it 'should escape strings' do
      cls.shellescape('echo "foo" > /tmp/baz').should == 'echo\ \\"foo\\"\ \>\ /tmp/baz'
    end
  end
end
