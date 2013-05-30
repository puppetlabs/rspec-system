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

  context 'legacy tests' do
    it 'cat /etc/hosts - test results using hash method' do
      shell 'cat /etc/hosts' do |r|
        r[:exit_code].should be_zero
        r[:stdout].should =~ /localhost/
      end
    end

    it 'cat /etc/hosts - using system_run' do
      system_run 'cat /etc/hosts' do |r|
        r.exit_code.should be_zero
        r.stdout.should =~ /localhost/
      end
    end

    it 'cat /tmp/setupblockold to ensure the system_setup_block still works' do
      shell 'cat /tmp/setupblockold' do |r|
        r.stdout.should =~ /foobar/
      end
    end
  end
end
