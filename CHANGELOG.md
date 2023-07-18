# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v0.20.1](https://github.com/albatrossflavour/puppet_os_patching/tree/v0.20.1) (2023-07-18)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/v0.20.0...v0.20.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- \#229 fix syntax error [\#230](https://github.com/albatrossflavour/puppet_os_patching/pull/230) ([albatrossflavour](https://github.com/albatrossflavour))

## [v0.20.0](https://github.com/albatrossflavour/puppet_os_patching/tree/v0.20.0) (2023-07-13)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.19.0...v0.20.0)

### Added

- \#227 Support for stdlib 9.x [\#228](https://github.com/albatrossflavour/puppet_os_patching/pull/228) ([albatrossflavour](https://github.com/albatrossflavour))
- Add RHEL9 to supported OS [\#225](https://github.com/albatrossflavour/puppet_os_patching/pull/225) ([tuxmea](https://github.com/tuxmea))
- \#217 add an apt update as part of the fact generation [\#224](https://github.com/albatrossflavour/puppet_os_patching/pull/224) ([albatrossflavour](https://github.com/albatrossflavour))
- \#222 Update os\_patching\_fact\_generation.sh [\#223](https://github.com/albatrossflavour/puppet_os_patching/pull/223) ([dpavlotzky](https://github.com/dpavlotzky))
- Don't record note from subscription-manager if enabled [\#221](https://github.com/albatrossflavour/puppet_os_patching/pull/221) ([jcpunk](https://github.com/jcpunk))
- Fix up the GitHub workflows [\#209](https://github.com/albatrossflavour/puppet_os_patching/pull/209) ([albatrossflavour](https://github.com/albatrossflavour))

### Fixed

- Add correct reboot detection for RHEL 8 and 9 [\#220](https://github.com/albatrossflavour/puppet_os_patching/pull/220) ([jcpunk](https://github.com/jcpunk))
- fix issue \#211 [\#219](https://github.com/albatrossflavour/puppet_os_patching/pull/219) ([brajjan](https://github.com/brajjan))
- Update Apt Support - Fixes \#217 [\#218](https://github.com/albatrossflavour/puppet_os_patching/pull/218) ([AMDHome](https://github.com/AMDHome))

## [0.19.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.19.0) (2023-02-26)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.18.0...0.19.0)

## [0.18.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.18.0) (2022-08-08)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/v0.17.0...0.18.0)

### Added

- updated RHEL regex to accommodate colon [\#216](https://github.com/albatrossflavour/puppet_os_patching/pull/216) ([prolixalias](https://github.com/prolixalias))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- adjust upper limit [\#214](https://github.com/albatrossflavour/puppet_os_patching/pull/214) ([prolixalias](https://github.com/prolixalias))

## [v0.17.0](https://github.com/albatrossflavour/puppet_os_patching/tree/v0.17.0) (2021-07-12)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/v0.16.0...v0.17.0)

### Fixed

- s/udpate/update [\#208](https://github.com/albatrossflavour/puppet_os_patching/pull/208) ([noahbliss](https://github.com/noahbliss))
- ensure that key exists while parsing json [\#203](https://github.com/albatrossflavour/puppet_os_patching/pull/203) ([maxadamo](https://github.com/maxadamo))

## [v0.16.0](https://github.com/albatrossflavour/puppet_os_patching/tree/v0.16.0) (2021-05-21)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.15.0...v0.16.0)

### Added

- Feature/204 hiera support [\#205](https://github.com/albatrossflavour/puppet_os_patching/pull/205) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/200 deltarpm [\#201](https://github.com/albatrossflavour/puppet_os_patching/pull/201) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/module hiera [\#199](https://github.com/albatrossflavour/puppet_os_patching/pull/199) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/174 windows update param [\#197](https://github.com/albatrossflavour/puppet_os_patching/pull/197) ([albatrossflavour](https://github.com/albatrossflavour))
- fix facter no longer working on puppet 7 [\#191](https://github.com/albatrossflavour/puppet_os_patching/pull/191) ([maxadamo](https://github.com/maxadamo))
- Working on \#180 : Adding rescue to allow code to continue after NoMet… [\#181](https://github.com/albatrossflavour/puppet_os_patching/pull/181) ([sharumpe](https://github.com/sharumpe))
- Change yum check-update to include valid entries instead of exclude invalid [\#175](https://github.com/albatrossflavour/puppet_os_patching/pull/175) ([freiheit](https://github.com/freiheit))
- Do not hardcode the path of AIO commands [\#168](https://github.com/albatrossflavour/puppet_os_patching/pull/168) ([smortex](https://github.com/smortex))
- Improve os\_patching::patch\_after\_healthcheck plan [\#167](https://github.com/albatrossflavour/puppet_os_patching/pull/167) ([kreeuwijk](https://github.com/kreeuwijk))
- Update README.md [\#162](https://github.com/albatrossflavour/puppet_os_patching/pull/162) ([LDaneliukas](https://github.com/LDaneliukas))
- Add FreeBSD support [\#156](https://github.com/albatrossflavour/puppet_os_patching/pull/156) ([smortex](https://github.com/smortex))

### Fixed

- puppetlabs-translate deprecated [\#189](https://github.com/albatrossflavour/puppet_os_patching/pull/189) ([binford2k](https://github.com/binford2k))
- expand filter inline and remove $FILTER variables [\#188](https://github.com/albatrossflavour/puppet_os_patching/pull/188) ([michael-letsengage](https://github.com/michael-letsengage))
- match Debian-Security [\#185](https://github.com/albatrossflavour/puppet_os_patching/pull/185) ([dgrote](https://github.com/dgrote))
- Fixing failing development tests [\#179](https://github.com/albatrossflavour/puppet_os_patching/pull/179) ([Tamerz](https://github.com/Tamerz))
- fix\(patch\_server\) change regex after yum history [\#171](https://github.com/albatrossflavour/puppet_os_patching/pull/171) ([bmx0r](https://github.com/bmx0r))
- Inconsistence between facter and manifest [\#164](https://github.com/albatrossflavour/puppet_os_patching/pull/164) ([elfranne](https://github.com/elfranne))

## [0.15.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.15.0) (2021-05-11)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.14.0...0.15.0)

### Added

- v0.15.0 release [\#196](https://github.com/albatrossflavour/puppet_os_patching/pull/196) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.14.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.14.0) (2021-05-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.12.0...0.14.0)

### Added

- \#149 allow Debian to run `apt-get autoremove` at reboot [\#151](https://github.com/albatrossflavour/puppet_os_patching/pull/151) ([albatrossflavour](https://github.com/albatrossflavour))
- Toggle to allow warnings to block patching \#143 [\#150](https://github.com/albatrossflavour/puppet_os_patching/pull/150) ([albatrossflavour](https://github.com/albatrossflavour))
- Updates to facter and bug fixes [\#148](https://github.com/albatrossflavour/puppet_os_patching/pull/148) ([albatrossflavour](https://github.com/albatrossflavour))
- Force usage of the 'C' locale [\#142](https://github.com/albatrossflavour/puppet_os_patching/pull/142) ([smortex](https://github.com/smortex))

### Fixed

- \#148 ensure versionlock file is there before we read it [\#154](https://github.com/albatrossflavour/puppet_os_patching/pull/154) ([albatrossflavour](https://github.com/albatrossflavour))
- Prevent error message to stderr on RedHat [\#153](https://github.com/albatrossflavour/puppet_os_patching/pull/153) ([smortex](https://github.com/smortex))
- Bugfix: Add missing dependency [\#144](https://github.com/albatrossflavour/puppet_os_patching/pull/144) ([theosotr](https://github.com/theosotr))
- The declared ISO format does not exist, had one extra `dd` [\#141](https://github.com/albatrossflavour/puppet_os_patching/pull/141) ([rnelson0](https://github.com/rnelson0))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Litmus updates and pre-v0.14.0 work [\#195](https://github.com/albatrossflavour/puppet_os_patching/pull/195) ([albatrossflavour](https://github.com/albatrossflavour))
- Master release - bug fixes and travis  [\#183](https://github.com/albatrossflavour/puppet_os_patching/pull/183) ([albatrossflavour](https://github.com/albatrossflavour))
- Fix issues with empty pre\_patching\_command entries [\#161](https://github.com/albatrossflavour/puppet_os_patching/pull/161) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge to production [\#160](https://github.com/albatrossflavour/puppet_os_patching/pull/160) ([albatrossflavour](https://github.com/albatrossflavour))
- clear out 'Obsoleting' entries [\#158](https://github.com/albatrossflavour/puppet_os_patching/pull/158) ([kreeuwijk](https://github.com/kreeuwijk))

## [0.12.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.12.0) (2019-08-21)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.11.1...0.12.0)

### Fixed

- \#138 - fix travis issues [\#139](https://github.com/albatrossflavour/puppet_os_patching/pull/139) ([albatrossflavour](https://github.com/albatrossflavour))
- \#129 restrictions on stdlib are too tight [\#130](https://github.com/albatrossflavour/puppet_os_patching/pull/130) ([albatrossflavour](https://github.com/albatrossflavour))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.12.0 release [\#152](https://github.com/albatrossflavour/puppet_os_patching/pull/152) ([albatrossflavour](https://github.com/albatrossflavour))
- V0.11.2 release [\#140](https://github.com/albatrossflavour/puppet_os_patching/pull/140) ([albatrossflavour](https://github.com/albatrossflavour))
- \#136 add html to the pdkignore [\#137](https://github.com/albatrossflavour/puppet_os_patching/pull/137) ([albatrossflavour](https://github.com/albatrossflavour))
- Issue/133 eventlog puppet agent 6.4.2 [\#134](https://github.com/albatrossflavour/puppet_os_patching/pull/134) ([nathangiuliani](https://github.com/nathangiuliani))
- Updated ReadMe [\#131](https://github.com/albatrossflavour/puppet_os_patching/pull/131) ([nathangiuliani](https://github.com/nathangiuliani))

## [0.11.1](https://github.com/albatrossflavour/puppet_os_patching/tree/0.11.1) (2019-05-07)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.11.0...0.11.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.11.1 release to master [\#132](https://github.com/albatrossflavour/puppet_os_patching/pull/132) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.11.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.11.0) (2019-05-03)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.10.0...0.11.0)

### Added

- Enable windows support [\#121](https://github.com/albatrossflavour/puppet_os_patching/pull/121) ([albatrossflavour](https://github.com/albatrossflavour))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- v0.11.0 release [\#126](https://github.com/albatrossflavour/puppet_os_patching/pull/126) ([albatrossflavour](https://github.com/albatrossflavour))
- \#124 promote new tests to development [\#125](https://github.com/albatrossflavour/puppet_os_patching/pull/125) ([albatrossflavour](https://github.com/albatrossflavour))
- Release to production in preparation for V0.11.0 release [\#123](https://github.com/albatrossflavour/puppet_os_patching/pull/123) ([albatrossflavour](https://github.com/albatrossflavour))
- Community information added [\#122](https://github.com/albatrossflavour/puppet_os_patching/pull/122) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.10.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.10.0) (2019-04-26)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.9.0...0.10.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Release to production [\#119](https://github.com/albatrossflavour/puppet_os_patching/pull/119) ([albatrossflavour](https://github.com/albatrossflavour))
- Add example plan [\#118](https://github.com/albatrossflavour/puppet_os_patching/pull/118) ([albatrossflavour](https://github.com/albatrossflavour))
- Resync development [\#116](https://github.com/albatrossflavour/puppet_os_patching/pull/116) ([albatrossflavour](https://github.com/albatrossflavour))
- Switch over to litmus tests [\#114](https://github.com/albatrossflavour/puppet_os_patching/pull/114) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/sles [\#113](https://github.com/albatrossflavour/puppet_os_patching/pull/113) ([JakeTRogers](https://github.com/JakeTRogers))

## [0.9.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.9.0) (2019-04-26)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.8.0...0.9.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Merge Litmus and Suse to production [\#115](https://github.com/albatrossflavour/puppet_os_patching/pull/115) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.8.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.8.0) (2019-01-24)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.7.0...0.8.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Changelog update [\#111](https://github.com/albatrossflavour/puppet_os_patching/pull/111) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge to master [\#110](https://github.com/albatrossflavour/puppet_os_patching/pull/110) ([albatrossflavour](https://github.com/albatrossflavour))
- Fact upload and stdlib fixes [\#109](https://github.com/albatrossflavour/puppet_os_patching/pull/109) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/pdqtest [\#108](https://github.com/albatrossflavour/puppet_os_patching/pull/108) ([albatrossflavour](https://github.com/albatrossflavour))
- Bugfix for filter code [\#105](https://github.com/albatrossflavour/puppet_os_patching/pull/105) ([albatrossflavour](https://github.com/albatrossflavour))
- Bugfix/filter [\#104](https://github.com/albatrossflavour/puppet_os_patching/pull/104) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#102 from albatrossflavour/development [\#103](https://github.com/albatrossflavour/puppet_os_patching/pull/103) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.7.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.7.0) (2018-12-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.6.4...0.7.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.7.0 release [\#102](https://github.com/albatrossflavour/puppet_os_patching/pull/102) ([albatrossflavour](https://github.com/albatrossflavour))
- metadata updates prior to 0.7.0 release [\#101](https://github.com/albatrossflavour/puppet_os_patching/pull/101) ([albatrossflavour](https://github.com/albatrossflavour))
- Additional filtering based on bug \#99 [\#100](https://github.com/albatrossflavour/puppet_os_patching/pull/100) ([albatrossflavour](https://github.com/albatrossflavour))
- Add confine to facter [\#98](https://github.com/albatrossflavour/puppet_os_patching/pull/98) ([albatrossflavour](https://github.com/albatrossflavour))
- filter out yum check-update security messages [\#97](https://github.com/albatrossflavour/puppet_os_patching/pull/97) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#87 from albatrossflavour/development [\#88](https://github.com/albatrossflavour/puppet_os_patching/pull/88) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.6.4](https://github.com/albatrossflavour/puppet_os_patching/tree/0.6.4) (2018-10-03)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.6.3...0.6.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Push to master \(0.6.4\) [\#87](https://github.com/albatrossflavour/puppet_os_patching/pull/87) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#85 from albatrossflavour/development [\#86](https://github.com/albatrossflavour/puppet_os_patching/pull/86) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.6.3](https://github.com/albatrossflavour/puppet_os_patching/tree/0.6.3) (2018-10-03)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.6.2...0.6.3)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.6.3 release [\#85](https://github.com/albatrossflavour/puppet_os_patching/pull/85) ([albatrossflavour](https://github.com/albatrossflavour))
- Debian fact improvements [\#84](https://github.com/albatrossflavour/puppet_os_patching/pull/84) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#82 from albatrossflavour/development [\#83](https://github.com/albatrossflavour/puppet_os_patching/pull/83) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.6.2](https://github.com/albatrossflavour/puppet_os_patching/tree/0.6.2) (2018-10-03)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.6.1...0.6.2)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.6.2 release [\#82](https://github.com/albatrossflavour/puppet_os_patching/pull/82) ([albatrossflavour](https://github.com/albatrossflavour))
- Enable security patching in debian again [\#81](https://github.com/albatrossflavour/puppet_os_patching/pull/81) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#79 from albatrossflavour/development [\#80](https://github.com/albatrossflavour/puppet_os_patching/pull/80) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.6.1](https://github.com/albatrossflavour/puppet_os_patching/tree/0.6.1) (2018-10-02)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.6.0...0.6.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fix a couple of strings issues [\#79](https://github.com/albatrossflavour/puppet_os_patching/pull/79) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge pull request \#77 from albatrossflavour/development [\#78](https://github.com/albatrossflavour/puppet_os_patching/pull/78) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.6.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.6.0) (2018-10-02)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.5.0...0.6.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Pull to master [\#77](https://github.com/albatrossflavour/puppet_os_patching/pull/77) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/data parser [\#76](https://github.com/albatrossflavour/puppet_os_patching/pull/76) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/clean cache [\#75](https://github.com/albatrossflavour/puppet_os_patching/pull/75) ([albatrossflavour](https://github.com/albatrossflavour))
- remove all reference to /opt/puppetlabs/facter/facts.d/os\_patching.yaml [\#72](https://github.com/albatrossflavour/puppet_os_patching/pull/72) ([GeoffWilliams](https://github.com/GeoffWilliams))
- Add acceptance testing, esure=\>absent, simplfify [\#71](https://github.com/albatrossflavour/puppet_os_patching/pull/71) ([GeoffWilliams](https://github.com/GeoffWilliams))
- Add reference.md [\#65](https://github.com/albatrossflavour/puppet_os_patching/pull/65) ([albatrossflavour](https://github.com/albatrossflavour))
- Bugfix/strings [\#64](https://github.com/albatrossflavour/puppet_os_patching/pull/64) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/move cache [\#63](https://github.com/albatrossflavour/puppet_os_patching/pull/63) ([albatrossflavour](https://github.com/albatrossflavour))
- Bugfix/facter path [\#62](https://github.com/albatrossflavour/puppet_os_patching/pull/62) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/rpm attribute fix [\#61](https://github.com/albatrossflavour/puppet_os_patching/pull/61) ([albatrossflavour](https://github.com/albatrossflavour))
- Warn user when task is not setup yet [\#53](https://github.com/albatrossflavour/puppet_os_patching/pull/53) ([GeoffWilliams](https://github.com/GeoffWilliams))
- Merge pull request \#50 from albatrossflavour/development [\#51](https://github.com/albatrossflavour/puppet_os_patching/pull/51) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.5.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.5.0) (2018-09-23)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.4.1...0.5.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Merge to master [\#50](https://github.com/albatrossflavour/puppet_os_patching/pull/50) ([albatrossflavour](https://github.com/albatrossflavour))
- Change the way we handle reboot logic [\#49](https://github.com/albatrossflavour/puppet_os_patching/pull/49) ([albatrossflavour](https://github.com/albatrossflavour))
- Resync to dev [\#47](https://github.com/albatrossflavour/puppet_os_patching/pull/47) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.4.1](https://github.com/albatrossflavour/puppet_os_patching/tree/0.4.1) (2018-09-16)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.4.0...0.4.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.4.1 [\#46](https://github.com/albatrossflavour/puppet_os_patching/pull/46) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.4.0](https://github.com/albatrossflavour/puppet_os_patching/tree/0.4.0) (2018-09-16)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.3.5...0.4.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- V0.4.0 release [\#45](https://github.com/albatrossflavour/puppet_os_patching/pull/45) ([albatrossflavour](https://github.com/albatrossflavour))
- Add extra error checking for the patch execution [\#44](https://github.com/albatrossflavour/puppet_os_patching/pull/44) ([albatrossflavour](https://github.com/albatrossflavour))
- Feature/facter error reporting [\#43](https://github.com/albatrossflavour/puppet_os_patching/pull/43) ([albatrossflavour](https://github.com/albatrossflavour))
- regex ignores pkgs starting with uppercase or digits [\#41](https://github.com/albatrossflavour/puppet_os_patching/pull/41) ([f3sty](https://github.com/f3sty))
- Bugfix/needs restarting improvements [\#38](https://github.com/albatrossflavour/puppet_os_patching/pull/38) ([albatrossflavour](https://github.com/albatrossflavour))
- Prod release [\#34](https://github.com/albatrossflavour/puppet_os_patching/pull/34) ([albatrossflavour](https://github.com/albatrossflavour))
- Fix parsing of install/installed [\#33](https://github.com/albatrossflavour/puppet_os_patching/pull/33) ([albatrossflavour](https://github.com/albatrossflavour))
- Fix issue with parsing of installed/install output from yum [\#30](https://github.com/albatrossflavour/puppet_os_patching/pull/30) ([albatrossflavour](https://github.com/albatrossflavour))
- Sync back to dev [\#28](https://github.com/albatrossflavour/puppet_os_patching/pull/28) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.3.5](https://github.com/albatrossflavour/puppet_os_patching/tree/0.3.5) (2018-08-16)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.3.4...0.3.5)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Pre-release updates [\#27](https://github.com/albatrossflavour/puppet_os_patching/pull/27) ([albatrossflavour](https://github.com/albatrossflavour))
- Release to master [\#26](https://github.com/albatrossflavour/puppet_os_patching/pull/26) ([albatrossflavour](https://github.com/albatrossflavour))
- Merge timeout fixes [\#25](https://github.com/albatrossflavour/puppet_os_patching/pull/25) ([albatrossflavour](https://github.com/albatrossflavour))
- Resync to development [\#24](https://github.com/albatrossflavour/puppet_os_patching/pull/24) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.3.4](https://github.com/albatrossflavour/puppet_os_patching/tree/0.3.4) (2018-08-10)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.3.3...0.3.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Pre release updates [\#23](https://github.com/albatrossflavour/puppet_os_patching/pull/23) ([albatrossflavour](https://github.com/albatrossflavour))
- Missed a new variable [\#22](https://github.com/albatrossflavour/puppet_os_patching/pull/22) ([albatrossflavour](https://github.com/albatrossflavour))
- Remove shell commands as much as possible [\#21](https://github.com/albatrossflavour/puppet_os_patching/pull/21) ([albatrossflavour](https://github.com/albatrossflavour))
- Ooops [\#20](https://github.com/albatrossflavour/puppet_os_patching/pull/20) ([albatrossflavour](https://github.com/albatrossflavour))
- Add cron job to refresh cache at reboot [\#19](https://github.com/albatrossflavour/puppet_os_patching/pull/19) ([albatrossflavour](https://github.com/albatrossflavour))
- Ensure we honour reboot\_override even if a reboot isn't required [\#18](https://github.com/albatrossflavour/puppet_os_patching/pull/18) ([albatrossflavour](https://github.com/albatrossflavour))
- Secure the params a little more [\#17](https://github.com/albatrossflavour/puppet_os_patching/pull/17) ([albatrossflavour](https://github.com/albatrossflavour))
- Updates to detect when reboots are required [\#16](https://github.com/albatrossflavour/puppet_os_patching/pull/16) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.3.3](https://github.com/albatrossflavour/puppet_os_patching/tree/0.3.3) (2018-08-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.3.2...0.3.3)

## [0.3.2](https://github.com/albatrossflavour/puppet_os_patching/tree/0.3.2) (2018-08-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.3.1...0.3.2)

## [0.3.1](https://github.com/albatrossflavour/puppet_os_patching/tree/0.3.1) (2018-08-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.2.1...0.3.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Resync to development [\#15](https://github.com/albatrossflavour/puppet_os_patching/pull/15) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.2.1](https://github.com/albatrossflavour/puppet_os_patching/tree/0.2.1) (2018-08-07)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.1.19...0.2.1)

### Added

- Major documentation update [\#14](https://github.com/albatrossflavour/puppet_os_patching/pull/14) ([albatrossflavour](https://github.com/albatrossflavour))

### Fixed

- rubocop [\#13](https://github.com/albatrossflavour/puppet_os_patching/pull/13) ([albatrossflavour](https://github.com/albatrossflavour))
- Rubocop updates [\#12](https://github.com/albatrossflavour/puppet_os_patching/pull/12) ([albatrossflavour](https://github.com/albatrossflavour))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Rubocop is on thin ice! [\#11](https://github.com/albatrossflavour/puppet_os_patching/pull/11) ([albatrossflavour](https://github.com/albatrossflavour))
- rubocop updates [\#10](https://github.com/albatrossflavour/puppet_os_patching/pull/10) ([albatrossflavour](https://github.com/albatrossflavour))
- Push to production [\#9](https://github.com/albatrossflavour/puppet_os_patching/pull/9) ([albatrossflavour](https://github.com/albatrossflavour))
- Start/end times added and history file fixed [\#8](https://github.com/albatrossflavour/puppet_os_patching/pull/8) ([albatrossflavour](https://github.com/albatrossflavour))
- Major update for all areas [\#7](https://github.com/albatrossflavour/puppet_os_patching/pull/7) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.1.19](https://github.com/albatrossflavour/puppet_os_patching/tree/0.1.19) (2018-07-09)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.1.17...0.1.19)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Feature/smarter tasks [\#6](https://github.com/albatrossflavour/puppet_os_patching/pull/6) ([albatrossflavour](https://github.com/albatrossflavour))

## [0.1.17](https://github.com/albatrossflavour/puppet_os_patching/tree/0.1.17) (2018-06-01)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/0.1.16...0.1.17)

## [0.1.16](https://github.com/albatrossflavour/puppet_os_patching/tree/0.1.16) (2018-05-29)

[Full Changelog](https://github.com/albatrossflavour/puppet_os_patching/compare/44fd883ad50bccbcd0843608f71b4e7499295af8...0.1.16)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
