require 'spec_helper_system'

describe "system_run:" do
  it "cat /etc/hosts" do
    system_run("cat /etc/hosts") do |r|
      r.exit_code.should == 0
      r.stdout.should =~ /localhost/
    end
  end

  it "cat /etc/hosts - test results using hash method" do
    system_run("cat /etc/hosts") do |r|
      r[:exit_code].should == 0
      r[:stdout].should =~ /localhost/
    end
  end

  it 'piping should be preserved' do
    system_run('rm -f /tmp/foo')
    system_run('echo "foo" > /tmp/foo') do |r|
      r.stderr.should == ''
      r.exit_code.should == 0
    end

    system_run('cat /tmp/foo') do |r|
      r.stdout.should =~ /foo/
      r.exit_code.should == 0
    end
    system_run('rm -f /tmp/foo')
  end

  it 'escape single quotes properly' do
    system_run('rm -f /tmp/foo')
    system_run("echo 'foo' > /tmp/foo") do |r|
      r.stderr.should == ''
      r.exit_code.should == 0
    end

    system_run('cat /tmp/foo') do |r|
      r.stdout.should =~ /foo/
      r.exit_code.should == 0
    end
    system_run('rm -f /tmp/foo')
  end
end
