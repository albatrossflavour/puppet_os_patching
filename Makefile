all:
	${MAKE} test

install_centos:
	bundle exec rake 'litmus:provision[docker, centos:6]'
	bundle exec rake 'litmus:provision[docker, centos:7]'

install_ubuntu:
	bundle exec rake 'litmus:provision[docker, ubuntu:16.04]'
	bundle exec rake 'litmus:provision[docker, ubuntu:18.04]'

install_module:
	bundle exec rake litmus:install_module

test:
	${MAKE} validate
	${MAKE} unit
	${MAKE} acceptance

validate:
	pdk validate

unit:
	pdk test unit

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
