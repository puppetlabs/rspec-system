require 'spec_helper_system'

describe "rcp:" do
  it 'check it works with block matchers' do
    rcp(
      :sp => fixture_root + 'example_dir',
      :dp => '/tmp/example_destination1'
    ) do |r|
      r.success.should be_true
    end

    shell 'cat /tmp/example_destination1/example_file' do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /Test content 1234/
    end
  end

  it 'check it works outside a block' do
    r = rcp(
      :sp => fixture_root + 'example_dir',
      :dp => '/tmp/example_destination2'
    )
    r.success.should be_true

    shell 'cat /tmp/example_destination2/example_file' do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /Test content 1234/
    end
  end

  it 'should support being passed a node as a string' do |r|
    r = rcp(
      :sp => fixture_root + 'example_dir',
      :dp => '/tmp/example_destination3',
      :destination_node => 'main',
    )
    r.success.should be_true

    shell 'cat /tmp/example_destination3/example_file' do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /Test content 1234/
    end
  end

  it 'should support being passed a node as an object' do |r|
    r = rcp(
      :sp => fixture_root + 'example_dir',
      :dp => '/tmp/example_destination3',
      :destination_node => node(:name => 'main'),
    )
    r.success.should be_true

    shell 'cat /tmp/example_destination3/example_file' do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /Test content 1234/
    end
  end
end
