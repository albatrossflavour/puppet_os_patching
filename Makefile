.PHONY: clean
.DEFAULT: validate

all:
	${MAKE} test

test:
	${MAKE} setup
	${MAKE} validate
	${MAKE} unit
	${MAKE} acceptance
	${MAKE} documentation

release:
	${MAKE} test
	${MAKE} release_updates

setup:
	/opt/puppetlabs/pdk/bin/pdk bundle install

validate:
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake metadata_lint
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake syntax
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake validate
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake rubocop
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake lint
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake check:git_ignore
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake check:dot_underscore
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake check:symlinks
	/opt/puppetlabs/pdk/bin/pdk bundle exec puppet-lint manifests

unit:
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake spec

acceptance:
	${MAKE} test_puppet6
	${MAKE} test_puppet7

test_puppet6:
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake 'litmus:provision_list[release_tests]'
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:install_agent[puppet6]
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:install_module
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:acceptance:parallel
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:tear_down

test_puppet7:
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake 'litmus:provision_list[release_tests]'
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:install_agent[puppet7]
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:install_module
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:acceptance:parallel
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:tear_down

teardown:
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake litmus:tear_down

documentation:
	/opt/puppetlabs/pdk/bin/pdk bundle exec puppet strings generate --format=markdown

release_updates:
	${MAKE} documentation
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake module:bump:minor
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake changelog
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake module:tag
	/opt/puppetlabs/pdk/bin/pdk bundle exec rake build

clean:
	@/opt/puppetlabs/pdk/bin/pdk bundle exec rake module:clean
