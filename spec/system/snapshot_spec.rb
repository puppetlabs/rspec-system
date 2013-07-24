require 'spec_helper_system'

describe "snapshot:" do
  describe snapshot() do
    its(:success) { should be_true }
  end

  describe revert() do
    its(:success) { should be_true }
  end
end
