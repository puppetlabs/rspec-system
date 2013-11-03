require 'spec_helper_system'

describe "base:" do
  it 'hostname variants should return the proper hostname' do
    shell 'hostname -f' do |r|
      r.stdout.should =~ /^main$/
      r.exit_code.should == 0
      r.stderr.should == ''
    end

    shell 'hostname' do |r|
      r.stdout.should =~ /^main$/
      r.exit_code.should == 0
      r.stderr.should == ''
    end
  end
end
