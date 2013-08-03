require 'spec_helper'

describe 'RSpecSystem::Helper' do
  let(:node) { mock() }

  before :each do
    # Always stub default_node
    RSpecSystem::Helper.any_instance.stubs(:default_node).returns(node)
  end

  context '#initialize' do
    it 'should be instantiatable' do
      RSpecSystem::Helper.any_instance.expects(:result_data).returns({})
      RSpecSystem::Helper.new({}, self)
    end

    it 'called as a block, should execute block and return itself' do
      RSpecSystem::Helper.any_instance.expects(:result_data)
      block_exec = nil
      RSpecSystem::Helper.new({}, self) do |r|
        r.class.should == RSpecSystem::Helper
        block_exec = true
      end
      block_exec.should be_true
    end

    it 'should convert :node using get_node_by_name when passed as a string' do
      RSpecSystem::Helper.any_instance.expects(:result_data)
      RSpecSystem::Helper.any_instance.expects(:get_node_by_name).with('mynode').returns(node)
      helper = RSpecSystem::Helper.new({:node => 'mynode'}, self)
      helper.opts[:node].should == node
    end
  end

  context '#refresh' do
    it 'should only be called once even if data requested again' do
      RSpecSystem::Helper.any_instance.expects(:execute).once.returns({:test => true})
      r = RSpecSystem::Helper.new({}, self)
      r[:test].should be_true
      r[:test].should be_true
    end

    it 'should call execute again' do
      RSpecSystem::Helper.any_instance.expects(:execute).once
      r = RSpecSystem::Helper.new({}, self)
      r.expects(:execute).once
      r.refresh
    end
  end

  context '#[]' do
    it 'should retrieve result data as a hash element' do
      rd = RSpecSystem::Result.new(:test => true)
      RSpecSystem::Helper.any_instance.expects(:result_data).twice.returns(rd)
      r = RSpecSystem::Helper.new({}, self)
      r[:test].should be_true
    end
  end

  context '#result_data' do
    it 'no initial result data request if lazy' do
      RSpecSystem::Helper.any_instance.expects(:result_data).never
      RSpecSystem::Helper.new({:lazy => true}, self)
    end

    it 'when lazy, will call result_data on first data request' do
      RSpecSystem::Helper.any_instance.expects(:result_data).never
      r = RSpecSystem::Helper.new({:lazy => true}, self)
      r.expects(:result_data).returns(RSpecSystem::Result.new(:test => true))
      r[:test].should be_true
    end
  end

  context '#to_hash' do
    it 'should call result_data.to_hash' do
      rd = mock()
      rd.expects(:to_hash).once.returns({:test => true})
      RSpecSystem::Helper.any_instance.stubs(:result_data).returns(rd)
      r = RSpecSystem::Helper.new({}, self)
      r.to_hash.should == {:test => true}
    end
  end
end
