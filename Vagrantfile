# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

$update_channel = "alpha"

$script = <<SCRIPT
# pass arguments to pool config vars
PREVIEW_REPOSITORY_URL=$1
MAX_CONTAINERS=$2

export PATH=$PATH:/usr/local/bin
cd /tmp

# build build-server
cd /app/docker/pool
docker build -t pool-server .
docker run -d -v /var/run/docker.sock:/var/run/docker.sock \
              --env MAX_CONTAINERS=${MAX_CONTAINERS}
              --env PREVIEW_REPOSITORY_URL=${PREVIEW_REPOSITORY_URL} \
              --name pool -p 80:80 -p 8080:8080 pool-server
hostname pool
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "coreos-alpha"
  config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % $update_channel

  config.vm.provider :vmware_fusion do |vb, override|
    override.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json" % $update_channel
  end

  config.dns.tld = "dev"
  config.vm.hostname = "pool"
  config.dns.patterns = [/^.*pool.dev$/]

  config.vm.network "private_network", ip: "192.168.20.10"

  config.vm.synced_folder ".", "/app", type: "nfs", 
              :mount_options   => ['nolock,vers=3,udp']

  config.vm.provision "shell" do |s|
     s.inline = $script
     # Set your repository for previewing by pool
     s.args = ["https://github.com/mookjp/flaskapp.git"]
     # Set the maximum number of containers runnning at the same time
     s.args << "5"
  end
     
  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end
end

VagrantDNS::Config.logger = Logger.new("dns.log")
