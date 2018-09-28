require "spec_helper"
require "puppet_x/os_patching/os_patching"

describe OsPatching::OsPatching do
  before {
    Facter.clear
  }

  it "popuplates warnings when updates haven't run in too long" do
    #hurray!
  end

  it "popuplates warnings when security updates haven't run in too long" do
    #hurray!
  end

  it "popuplates warnings when invalid blacklist found" do
    #hurray!
  end

  it "popuplates warnings when updates file missing" do
    #hurray!
  end

  it "popuplates warnings when reboot_required filetime is too old" do
    #hurray!
  end
end