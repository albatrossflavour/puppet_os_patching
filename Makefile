all:
	cd .pdqtest && pwd && bundle exec pdqtest all
	$(MAKE) docs

fast:
	cd .pdqtest && pwd && bundle exec pdqtest fast

shell:
	cd .pdqtest && pwd && bundle exec pdqtest --keep-container acceptance

setup:
	cd .pdqtest && pwd && bundle exec pdqtest setup

shellnopuppet:
	cd .pdqtest && pwd && bundle exec pdqtest shell

logical:
	cd .pdqtest && pwd && bundle exec pdqtest syntax
	cd .pdqtest && pwd && bundle exec pdqtest rspec
	$(MAKE) docs

#nastyhack:
#	# fix for - https://tickets.puppetlabs.com/browse/PDK-1192
#	find vendor -iname '*.pp' -exec rm {} \;

pdqtestbundle:
	# Install all gems into _normal world_ bundle so we can use all of em
	cd .pdqtest && pwd && bundle install

docs:
	cd .pdqtest && pwd && bundle exec "cd ..&& puppet strings"


Gemfile.local:
	echo "[🐌] Creating symlink and running pdk bundle..."
	ln -s Gemfile.project Gemfile.local
	$(MAKE) pdkbundle

pdkbundle:
	pdk bundle install
