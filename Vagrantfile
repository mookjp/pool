# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

$script = <<SCRIPT
export PATH=$PATH:/usr/local/bin
cd /tmp

# Set time
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Japan /etc/localtime

rpm -ivh http://ftp-srv2.kddilabs.jp/Linux/distributions/fedora/epel/6/x86_64/epel-release-6-8.noarch.rpm
# Install required packages
yum update -y
yum install -y bison
yum install -y gcc-c++
yum install -y docker-io
yum install -y git
yum install -y glibc-headers
yum install -y hiredis-devel
yum install -y httpd
yum install -y httpd-devel
yum install -y libyaml-devel
yum install -y openssl-devel
yum install -y readline
yum install -y readline-devel
yum install -y tar
yum install -y zlib
yum install -y zlib-devel

# Install Ruby
git clone https://github.com/sstephenson/ruby-build.git /opt/ruby-build
chmod u+x /opt/ruby-build/install.sh
/opt/ruby-build/install.sh
/usr/local/bin/ruby-build 2.1.2 /opt/ruby-2.1.2
ln -s /opt/ruby-2.1.2/bin/ruby /usr/local/bin/ruby

# Install mod_mruby
git clone https://github.com/matsumoto-r/mod_mruby.git /tmp/mod_mruby
cd /tmp/mod_mruby
chmod u+x /tmp/mod_mruby/build.sh
./build.sh
make install

# Install required gems
/usr/local/bin/ruby gem install git
/usr/local/bin/ruby gem install em-websocket

# hostname settings
cp /app/provisioning/network /etc/sysconfig/network
cp /app/provisioning/hosts /etc/sysconfig/hosts
hostname pool

# Apache settings
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
cp /app/provisioning/httpd.conf /etc/httpd/conf/httpd.conf
cp /app/provisioning/mruby.conf /etc/httpd/conf.d/mruby.conf

# Add apache to docker group to access docker sockfile
usermod -G docker apache

# Start services
service network restart
service httpd start
service docker start
# Start build server
/usr/local/bin/ruby /app/builder/build_server.rb &
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "centos65"
  config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v6.5.3/centos65-x86_64-20140116.box"

  config.dns.tld = "dev"
  config.vm.hostname = "pool"
  config.dns.patterns = [/^.*pool.dev$/]

  config.vm.network "private_network", ip: "192.168.20.10"

  config.vm.synced_folder ".", "/app", type: "nfs"

  config.vm.provision "shell", inline: $script
end

VagrantDNS::Config.logger = Logger.new("dns.log")
