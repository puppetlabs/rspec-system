require 'spec_helper_system'

describe "base:" do
  it 'hostname -f returns something valid' do
    shell 'hostname -f' do |r|
      r.stdout.should =~ /^main/
      r.exit_code.should == 0
      r.stderr.should == ''
    end
  end
end
