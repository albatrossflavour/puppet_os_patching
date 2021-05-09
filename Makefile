all:
	${MAKE} test

test:
	${MAKE} setup
	${MAKE} validate
	${MAKE} unit
	${MAKE} acceptance
	${MAKE} documentation

setup:
	pdk bundle install

validate:
	pdk bundle exec rake metadata_lint
	pdk bundle exec rake syntax
	pdk bundle exec rake validate
	pdk bundle exec rake rubocop
	pdk bundle exec rake lint
	pdk bundle exec rake check:git_ignore
	pdk bundle exec rake check:dot_underscore
	pdk bundle exec rake check:symlinks
	pdk bundle exec puppet-lint manifests

unit:
	pdk bundle exec rake spec

acceptance:
	#${MAKE} test_puppet5
	${MAKE} test_puppet6
	#${MAKE} test_puppet7

test_puppet6:
	pdk bundle exec rake 'litmus:provision_list[release_tests]'
	pdk bundle exec rake litmus:install_agent[puppet6]
	pdk bundle exec rake litmus:install_module
	pdk bundle exec rake litmus:acceptance:parallel
	pdk bundle exec rake litmus:tear_down

teardown:
	pdk bundle exec rake litmus:tear_down

documentation:
	pdk bundle exec puppet strings generate --format=markdown
