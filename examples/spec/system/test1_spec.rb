require 'spec_helper'

describe "test1" do
  it 'run test1 - part1' do
    shell "cat /etc/resolv.conf"
  end

  it 'run test1 - part2' do
    shell "cat /etc/issue"
  end
end
