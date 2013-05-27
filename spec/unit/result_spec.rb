require 'spec_helper'

describe RSpecSystem::Result do
  it 'should allow you to query using methods' do
    result = subject.class.new(:foo => 'bar')
    result.foo.should == 'bar'
  end

  it 'should allow you to query using hash queries' do
    result = subject.class.new(:foo => 'bar')
    result[:foo].should == 'bar'
  end
end
