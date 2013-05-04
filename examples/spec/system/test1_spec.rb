require 'spec_helper'

describe "test1" do
  it 'run test1 - part1' do
    system_run("cat /etc/resolv.conf")
  end

  it 'run test1 - part2' do
    system_run("cat /etc/issue")
  end
end
