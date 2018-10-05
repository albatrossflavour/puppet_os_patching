ln -fs /opt/puppetlabs/bin/facter /usr/local/bin/facter
cp /testcase/spec/mock/facts_face.rb /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/face/facts.rb

# Cleanup state from previous runs
if [ -d /tmp/os_patching ] ; then
    rm -rf /tmp/os_patching
fi
mkdir /tmp/os_patching

if [ -d /var/cache/os_patching ] ; then
    rm -rf /var/cache/os_patching
fi
mkdir -p /var/cache/os_patching

# Fake apt-get
if [ -f /usr/bin/apt-get ] ; then
    rm /usr/bin/apt-get
fi
ln -fs /testcase/spec/mock/apt-get.py /usr/bin/apt-get

# Fake apt
if [ -f /usr/bin/apt ] ; then
    rm /usr/bin/apt
fi
ln -fs /testcase/spec/mock/apt-get.py /usr/bin/apt


# Fake yum
if [ -f /usr/bin/yum ] ; then
    rm /usr/bin/yum
fi
ln -fs /testcase/spec/mock/yum.py /usr/bin/yum

# Fake shutdown
if [ -f /sbin/shutdown ] ; then
    rm /sbin/shutdown
fi
ln -fs /testcase/spec/mock/shutdown.py /sbin/shutdown