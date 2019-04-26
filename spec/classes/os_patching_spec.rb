require 'spec_helper'

describe 'os_patching' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      case os_facts[:osfamily]
      when 'RedHat'
        context 'with package management enabled' do
          let(:params) {
            {
              'manage_yum_utils'           => true,
              'manage_delta_rpm'           => true,
              'manage_yum_plugin_security' => true,
            }
          }
          it { is_expected.to contain_package('deltarpm') }
          it { is_expected.to contain_package('yum-utils') }
          it { is_expected.to contain_package('yum-plugin-security') }
        end
        context 'with package management default' do
          it { is_expected.not_to contain_package('deltarpm') }
          it { is_expected.not_to contain_package('yum-utils') }
          it { is_expected.not_to contain_package('yum-plugin-security') }
        end
      end

      context 'with reboot_override => always' do
        let(:params) { {'reboot_override' => 'always'} }
        it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with({
          'ensure' => 'file',
          'owner'  => 'root',
          'group'  => 'root',
          'mode'   => '0644',
        })}
        it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with_content(/^always$/)}
      end

      context 'with reboot_override => never' do
        let(:params) { {'reboot_override' => 'never'} }
        it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with({
          'ensure' => 'file',
          'owner'  => 'root',
          'group'  => 'root',
          'mode'   => '0644',
        })}
        it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with_content(/^never$/)}
      end

      context 'with reboot_override => foobar' do
        let(:params) { {'reboot_override' => 'foobar'} }
        it { is_expected.to compile.and_raise_error(/reboot_override/) }
      end

      context 'with patch_window => $#&!RYYQ!' do
        let(:params) { {'patch_window' => '(((((##(@(!$#&!RYYQ!'} }
        it { is_expected.to compile }
      end

      context 'with patch_window => Week3' do
        let(:params) { {'patch_window' => 'Week3'} }
        it { is_expected.to contain_file('/var/cache/os_patching/patch_window').with({
          'ensure' => 'file',
          'owner'  => 'root',
          'group'  => 'root',
          'mode'   => '0644',
        })}
        it { is_expected.to contain_file('/var/cache/os_patching/patch_window').with_content(/^Week3$/)}
      end

      context 'with blackout window set' do
        let(:params) {
          {
            'blackout_windows' => { 'End of year change freeze': { 'start': '2018-12-15T00:00:00+10:00', 'end': '2019-01-15T23:59:59+10:00' } }
          }
        }
        it { is_expected.to contain_file('/var/cache/os_patching/blackout_windows').with({
          'ensure' => 'file',
          'owner'  => 'root',
          'group'  => 'root',
          'mode'   => '0644',
        })}
        it { is_expected.to contain_file('/var/cache/os_patching/blackout_windows').with_content(/End of year change/)}
      end

      it { is_expected.to compile }
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('os_patching') }
      it { is_expected.to contain_file('/var/cache/os_patching').with({
        'ensure' => 'directory',
        'owner'  => 'root',
        'group'  => 'root',
        'mode'   => '0644',
      })}

      it { is_expected.to contain_file('/var/cache/os_patching/blackout_windows').with({
        'ensure' => 'absent',
      })}

      it { is_expected.to contain_file('/var/cache/os_patching/patch_window').with({
        'ensure' => 'absent',
      })}

      it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with({
        'ensure' => 'file',
        'owner'  => 'root',
        'group'  => 'root',
        'mode'   => '0644',
      })}

      it { is_expected.to contain_file('/var/cache/os_patching/reboot_override').with_content(/^default$/)}

      it { is_expected.to contain_file('/usr/local/bin/os_patching_fact_generation.sh').with({
        'ensure' => 'file',
        'owner'  => 'root',
        'group'  => 'root',
        'mode'   => '0700',
      })}

      it { is_expected.to contain_cron('Cache patching data').with_ensure('present') }
      it { is_expected.to contain_cron('Cache patching data at reboot').with_ensure('present') }
      it { is_expected.to contain_exec('os_patching::exec::fact') }
      it { is_expected.to contain_exec('os_patching::exec::fact_upload') }

      context 'purge module' do
        let(:params) { {'ensure' => 'absent'} }
        it { is_expected.to contain_file('/var/cache/os_patching').with({
          'ensure' => 'absent',
        })}
      end
    end
  end
end
