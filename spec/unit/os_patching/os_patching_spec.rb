require 'spec_helper'
require 'puppet_x/os_patching/os_patching'
require 'date'

# rubocop:disable RSpec/DescribedClass
describe OsPatching::OsPatching do
  before(:each) do
    Facter.clear
    OsPatching::OsPatching.reset
  end

  it 'populates warnings when updates not run in long time' do
    Dir.mktmpdir do |tmpdir|
      # Create some old data
      old_time = (Date.today.to_date - 30).to_time

      file = File.join(tmpdir, 'package_updates')
      File.open(file, 'w') { |f| f.write('all_packages_outdated') }
      File.utime(File.atime(file), old_time, file)

      # Read the facts from this directory, we should have a warning
      OsPatching::OsPatching.use_testcase tmpdir
      is_fact = OsPatching::OsPatching.fact

      expect(is_fact['warnings']['update_file_time']).to match(/not been updated/)
    end
  end

  it 'populates warnings when security updates not run in long time' do
    Dir.mktmpdir do |tmpdir|
      # Create some old data
      old_time = (Date.today.to_date - 30).to_time

      file = File.join(tmpdir, 'security_package_updates')
      File.open(file, 'w') { |f| f.write('all_packages_outdated') }
      File.utime(File.atime(file), old_time, file)

      # Read the facts from this directory, we should have a warning
      OsPatching::OsPatching.use_testcase tmpdir
      is_fact = OsPatching::OsPatching.fact

      expect(is_fact['warnings']['sec_update_file_time']).to match(/not been updated/)
    end
  end

  it 'populates warnings when invalid blacklist found' do
    OsPatching::OsPatching.use_testcase 'spec/testcase/invalid_blacklist'
    is_fact = OsPatching::OsPatching.fact

    expect(is_fact['warnings']['blackouts']).to match(/Invalid blackout/)
  end

  it 'populates warnings when security updates/updates file missing' do
    OsPatching::OsPatching.use_testcase 'spec/testcase/missing_files'
    is_fact = OsPatching::OsPatching.fact

    expect(is_fact['warnings']['update_file']).to match(
      %r{file not found reading spec/testcase/missing_files/package_updates},
    )
    expect(is_fact['warnings']['security_update_file']).to match(
      %r{file not found at spec/testcase/missing_files/security_package_updates},
    )
  end

  it 'populates warnings when reboot_required filetime is too old' do
    Dir.mktmpdir do |tmpdir|
      # Create some old data
      old_time = (Date.today.to_date - 30).to_time

      file = File.join(tmpdir, 'reboot_required')
      File.open(file, 'w') { |f| f.write('outdated') }
      File.utime(File.atime(file), old_time, file)

      # Read the facts from this directory, we should have a warning
      OsPatching::OsPatching.use_testcase tmpdir
      is_fact = OsPatching::OsPatching.fact

      expect(is_fact['warnings']['reboot_required_file_time']).to match(/not been updated/)
    end
  end

  it 'builds the main fact correctly' do
    # Data obtained from running `puppet facts` for
    # albatrossflavour-os_patching (v0.6.4)
    should_fact = JSON.parse(File.read('spec/testcase/os_patching-0.6.4.json'))

    # Use static testcase data obtained from same box above command was run on
    # and then have the fact parsing code evaluate it
    OsPatching::OsPatching.use_testcase 'spec/testcase/regular'
    is_fact = OsPatching::OsPatching.fact

    # we should have the exact same data parsed
    expect(should_fact == is_fact).to be true
  end
end
