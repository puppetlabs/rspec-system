require 'spec_helper_system'

describe "rcp:" do
  it 'check rcp works' do
    rcp(
      :sp => fixture_root + 'example_dir',
      :dp => '/tmp/example_destination'
    )

    shell 'cat /tmp/example_destination/example_file' do |r|
      r.exit_code.should be_zero
      r.stdout.should =~ /Test content 1234/
    end
  end

  context 'legacy tests' do
    it 'check system_rcp works' do
      system_rcp(
        :sp => fixture_root + 'example_dir',
        :dp => '/tmp/example_destination'
      )

      shell 'cat /tmp/example_destination/example_file' do |r|
        r.exit_code.should be_zero
        r.stdout.should =~ /Test content 1234/
      end
    end
  end
end
