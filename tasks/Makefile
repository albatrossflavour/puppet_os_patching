all:
	# colon not suppoesd to be in makefile, use \072 instead
	cat ../lib/puppet_x/os_patching/os_patching.rb > clean_cache.rb
	echo "# rubocop\072disable Layout/LeadingCommentSpace" >> clean_cache.rb
	cat ../tasks.real/clean_cache_real.rb >> clean_cache.rb
	chmod +x clean_cache.rb
	cat ../lib/puppet_x/os_patching/os_patching.rb > patch_server.rb
	echo "# rubocop\072disable Layout/LeadingCommentSpace" >> patch_server.rb
	cat ../tasks.real/patch_server_real.rb >> patch_server.rb
	chmod +x patch_server.rb
	cat ../lib/puppet_x/os_patching/os_patching.rb > refresh_fact.rb
	echo "# rubocop\072disable Layout/LeadingCommentSpace" >> refresh_fact.rb
	cat ../tasks.real/refresh_fact_real.rb >> refresh_fact.rb
	chmod +x refresh_fact.rb
