require 'spec_helper_system'

describe "shell:" do
  it 'check /tmp/setupblock to ensure before :suite executed' do
    shell 'cat /tmp/setupblock' do |r|
      r.stdout.should =~ /foobar/
    end
  end

  it "cat /etc/hosts" do
    shell "cat /etc/hosts" do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /localhost/
    end
  end

  it 'ensure it can be used outside a block' do
    shell 'echo foobar > /tmp/foobarbaz'
    r = shell 'cat /tmp/foobarbaz'
    r.stdout.should =~ /foobar/
  end

  it "cat /etc/hosts - test results using hash method" do
    shell "cat /etc/hosts" do |r|
      r[:exit_code].should be_zero
      r[:stdout].should =~ /localhost/
    end
  end

  it 'piping should be preserved' do
    shell 'rm -f /tmp/foo'
    shell 'echo "foo bar baz" > /tmp/foo' do |r|
      r.stderr.should be_empty
      r.exit_code.should be_zero
    end

    shell 'cat /tmp/foo' do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should be_zero
    end
    shell 'rm -f /tmp/foo'
  end

  it 'escape single quotes properly' do
    shell 'rm -f /tmp/foo'
    shell "echo 'foo bar baz' > /tmp/foo" do |r|
      r.stderr.should be_empty
      r.exit_code.should be_zero
    end

    shell 'cat /tmp/foo' do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should be_zero
    end
    shell 'rm -f /tmp/foo'
  end

  it 'escape all quotes properly' do
    shell 'rm -f ~vagrant/foo'
    shell "su - vagrant -c 'echo \"foo bar baz\" > ~/foo'" do |r|
      r.stderr.should be_empty
      r.exit_code.should be_zero
    end

    shell 'cat ~vagrant/foo' do |r|
      r.stdout.should =~ /foo bar baz/
      r.exit_code.should be_zero
    end
    shell 'rm -f ~vagrant/foo'
  end

  it 'a string of commands should succeed' do
    r = shell <<-EOS.gsub(/^ {6}/, '')
      rm /tmp/foo
      echo 'foo bar baz' > /tmp/foo
      cat /tmp/foo
      rm /tmp/foo
    EOS
    r.stdout.should =~ /foo bar baz/
    r.exit_code.should be_zero
  end

  describe 'use in subject' do
    context shell 'cat /etc/hosts' do
      its(:stdout) { should =~ /localhost/ }
      its(:exit_code) { should be_zero }
      its(:stderr) { should be_empty }
    end
  end

  context 'should not be lazy in a before :each block' do
    before :each do
      shell('echo foobarbaz > /tmp/eachblock')
    end
    context shell 'cat /tmp/eachblock' do
      its(:stdout) { should =~ /foobarbaz/ }
    end
  end

  context 'should not be lazy in a before inside its own context' do
    context shell 'cat /tmp/eachblock2' do
      before :each do
        shell('echo foobarbaz > /tmp/eachblock2')
      end
      its(:stdout) { should =~ /foobarbaz/ }
    end
  end

  it 'should be able to make shell lazy' do
    shell(:c => 'echo foobarbaz > /tmp/forcelazy', :lazy => true)
    shell 'cat /tmp/forcelazy' do |r|
      r.stdout.should be_empty
    end
  end

  context 'legacy tests' do
    it 'cat /etc/hosts - test results using hash method' do
      shell 'cat /etc/hosts' do |r|
        r[:exit_code].should be_zero
        r[:stdout].should =~ /localhost/
      end
    end
  end
end

# Test as a top-level subject
describe shell('cat /etc/hosts') do
  its(:stdout) { should =~ /localhost/ }
  its(:stderr) { should be_empty }
  its(:exit_code) { should be_zero }
end

# Test as an explicit subject, this is a bad example but put here for complete-
# ness. The problem is that the subject will get called each time, so its not
# recommended to use it ths way.
describe 'cat /etc/hosts' do
  subject { shell('cat /etc/hosts') }
  its(:stdout) { should =~ /localhost/ }
  its(:stderr) { should be_empty }
  its(:exit_code) { should be_zero }
end
