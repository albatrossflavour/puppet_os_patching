.PHONY: clean
.DEFAULT: validate

# Use PDK if it's installed, otherwise just use native bundler
ifeq ($(wildcard /opt/puppetlabs/pdk/bin/pdk),)
PDK =
else
PDK = /opt/puppetlabs/pdk/bin/pdk
endif

all: test

test: validate unit acceptance documentation

release: test release_updates

acceptance: test_puppet6 test_puppet7

setup:
	${PDK} bundle install

validate: setup
	${PDK} bundle exec rake metadata_lint
	${PDK} bundle exec rake syntax
	${PDK} bundle exec rake validate
	${PDK} bundle exec rake rubocop
	${PDK} bundle exec rake lint
	${PDK} bundle exec rake check:git_ignore
	${PDK} bundle exec rake check:dot_underscore
	${PDK} bundle exec rake check:symlinks
	${PDK} bundle exec puppet-lint manifests

unit: setup
	${PDK} bundle exec rake spec

test_puppet6: setup
	${PDK} bundle exec rake 'litmus:provision_list[release_tests]'
	${PDK} bundle exec rake litmus:install_agent[puppet6]
	${PDK} bundle exec rake litmus:install_module
	${PDK} bundle exec rake litmus:acceptance:parallel
	${PDK} bundle exec rake litmus:tear_down

test_puppet7: setup
	${PDK} bundle exec rake 'litmus:provision_list[release_tests]'
	${PDK} bundle exec rake litmus:install_agent[puppet7]
	${PDK} bundle exec rake litmus:install_module
	${PDK} bundle exec rake litmus:acceptance:parallel
	${PDK} bundle exec rake litmus:tear_down

teardown: setup
	${PDK} bundle exec rake litmus:tear_down

documentation: setup
	${PDK} bundle exec puppet strings generate --format=markdown

release_updates: setup documentation
	${PDK} bundle exec rake module:bump:minor
	${PDK} bundle exec rake changelog
	${PDK} bundle exec rake module:tag
	${PDK} bundle exec rake build

clean: setup
	${PDK} bundle exec rake module:clean
