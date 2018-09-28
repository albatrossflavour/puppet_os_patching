require 'puppet_x/os_patching/os_patching'
# Ensure that this fact does not try to be loaded
# on old (pre v.2) versions of facter as it uses
# aggregate facts
if Facter.value(:facterversion).split('.')[0].to_i < 2
  Facter.add('os_patching') do
    setcode do
      'not valid on legacy facter versions'
    end
  end
else
  Facter.add('os_patching') do
    setcode do
      OsPatching::OsPatching.fact
    end
  end
end
