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
    system_run('echo "foo bar baz" > /tmp/foo') do |r|
      r.stderr.should == ''
      r.exit_code.should == 0
    end

    system_run('cat /tmp/foo') do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should == 0
    end
    system_run('rm -f /tmp/foo')
  end

  it 'escape single quotes properly' do
    system_run('rm -f /tmp/foo')
    system_run("echo 'foo bar baz' > /tmp/foo") do |r|
      r.stderr.should == ''
      r.exit_code.should == 0
    end

    system_run('cat /tmp/foo') do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should == 0
    end
    system_run('rm -f /tmp/foo')
  end

  it 'escape all quotes properly' do
    system_run('rm -f ~vagrant/foo')
    system_run("su - vagrant -c 'echo \"foo bar baz\" > ~/foo'") do |r|
      r.stderr.should == ''
      r.exit_code.should == 0
    end

    system_run('cat ~vagrant/foo') do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should == 0
    end
    system_run('rm -f ~vagrant/foo')
  end

  it 'a string of commands should succeed' do
    r = system_run(<<-EOS.gsub(/^ {6}/, ''))
      rm /tmp/foo
      echo 'foo bar baz' > /tmp/foo
      cat /tmp/foo
      rm /tmp/foo
    EOS
    r.stdout.should =~ /foo bar baz/
    r.exit_code.should == 0
  end
end
