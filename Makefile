all:
	${MAKE} test

install_centos:
	bundle exec rake 'litmus:provision_list[travis_el]'

install_ubuntu:
	bundle exec rake 'litmus:provision_list[travis_deb]'

install_module:
	bundle exec rake litmus:install_module

test:
	${MAKE} validate
	${MAKE} unit
	${MAKE} acceptance

validate:
	bundle exec rake metadata_lint
	bundle exec rake syntax
	bundle exec rake validate
	bundle exec rake rubocop
	bundle exec rake check:git_ignore

unit:
	bundle exec rake spec

acceptance:
	${MAKE} test_puppet5
	${MAKE} test_puppet6

test_puppet6:
	${MAKE} install_centos
	${MAKE} install_ubuntu
	bundle exec rake litmus:install_agent[puppet6]
	${MAKE} install_module
	bundle exec rake litmus:acceptance:parallel && ${MAKE} teardown

test_puppet5:
	${MAKE} install_centos
	${MAKE} install_ubuntu
	bundle exec rake litmus:install_agent[puppet5]
	${MAKE} install_module
	bundle exec rake litmus:acceptance:parallel && ${MAKE} teardown

teardown:
	bundle exec rake litmus:tear_down

shell:
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost -p 2225
