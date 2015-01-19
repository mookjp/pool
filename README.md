🐳 pool 🐳
===

[![wercker status](https://app.wercker.com/status/2581a9ed9a58b4a95dadc2a33b639d83/m/master "wercker status")](https://app.wercker.com/project/bykey/2581a9ed9a58b4a95dadc2a33b639d83)

The simplest proxy service to access your Dockerized web application by Git commit-id, branch or tag.

<p align="center">
<img src="https://cloud.githubusercontent.com/assets/1519309/4186488/54415ec4-3761-11e4-9b13-41e09653945f.gif">
</p>

You can build and run your web application as a Docker container just to access
`http://<git-commit-id, branch or tag>.pool.dev` for example.

---

- [Requirements](#requirements)
- [Quick start](#quick-start)
  - [Vagrant](#vagrant)
    - [Launch Vagrant box](#launch-vagrant-box)
    - [Parameters](#parameters)
    - [Access web application](#access-web-application)
  - [AWS EC2 instances](#aws-ec2-instances)
    - [Instalation for Amazon linux](#instalation-for-amazon-linux)
    - [Parameters of init-script](#parameters-of-init-script)
- [How it works](#how-it-works)
- [Contributors](#contributors)

## Requirements

* [Docker](https://www.docker.com/) should be installed on your host machine
    * Our `Vagrantfile` is configured to have docker so you don't have to care about it if you try to run on Vagrant
* Web application which you want to preview should be on Git repository
* Git repository of the application has `Dockerfile` on root of the repository
    * `Dockerfile` is for a container which the application is going to be run

## Quick start

### Vagrant

You can run pool on your local [Vagrant](https://www.vagrantup.com/) environment also.

#### Launch Vagrant box

It needs to install [vagrant dns plugin](https://github.com/BerlinVagrant/vagrant-dns) before `vagrant up`. Just run after vagrant was installed:

```sh
vagrant plugin install vagrant-dns
vagrant dns --install
vagrant dns --start
```

then run:

```
vagrant up
```

#### Parameters

You can give some configuration to `pool` in `Vagrantfile`.

Currently we some configurations for `pool`.

* github-bot
    * It enables github integration
* Git repository url
    * Your Git repository URL
* Maximum numbers of comtainers
    * `pool` kills containers if the number of containers are over than this number automatically
* Hostname
    * Hostname you want to use to access the environment

You can rewrite [Vagrantfile](https://github.com/mookjp/pool/blob/master/Vagrantfile#L29-L37) like:

```ruby
# If you'd like to enable github integration, uncomment below
s.args << "--github-bot"

# Set your repository for previewing by pool
s.args << "https://github.com/mookjp/flaskapp.git"
# Set the maximum number of containers runnning at the same time
s.args << "5"
# Set POOL_BASE_DOMAIN
s.args << [pool_hostname, pool_tld].join(".")
```

#### Access web application

To watch the web application on `pool`, you can do it just to access `http://<git-commit-id>.pool.dev` with your **browser**.

In the default setting, `pool` is configured for the web application maintained in the [mookjp/flaskapp](https://github.com/mookjp/flaskapp) repository.
You can see the flask app (which just outputs 'hello world') just visiting `http://c8f48c60088bbae0d0fb25ed5fd04f4442b58617.pool.dev/` or `http://master.pool.dev/`.

### AWS EC2 instances

Following is an example to install `pool` to Amazon Linux.

#### Instalation for Amazon linux

To install `pool` on your Amazon Linux, use following userdata. This example is for Amazon Linux AMI `amzn-ami-hvm-2014.03.2.x86_64-ebs (ami-29dc9228)`

```sh
#!/bin/sh
# Setup script for pool
# NOTE: Run it as root
yum install -y git
yum install -y docker

# Install latest Docker
service docker stop
curl https://get.docker.com/builds/Linux/x86_64/docker-latest -o /tmp/docker
chmod +x /tmp/docker
cp /tmp/docker /usr/bin/docker
service docker start

# Download pool then run pool container
git clone https://github.com/mookjp/pool.git /app

# You can create `pool` image and run to execute `init_host_server` script.
# It gets 3 parameters:
# 1) Git repository URL
# 2) Maximum number of containers of web application
# 3) Hostname
/app/scripts/init_host_server "https://github.com/mookjp/flaskapp.git" 5 "dev.prevs.io"
```

#### Parameters of init-script

`pool/scripts/init_host_server` is a small util script to run `pool` container. It gets 3 parameters:

1. Git repository URL
2. Maximum number of containers of web application
3. Hostname. you can get your hostname from your container of application
   as environment valuable; `POOL_BASE_DOMAIN` so that you can set configuration
   related to hostname inside your container

## How it works

The part of proxy in `pool` accesses your Git repository with commit id given as
hostname then checkout source with Dockerfile.
Dockerfile should be on the root of the repository.
After checkout files, the container will be built by the Dockerfile
and port is linked with front automatically. All you can do is just to access
by URL like `http://<git-commit-id, branch or tag>.pool.dev`.

`pool` consists of two modules; proxy hook and container builder.
`handlers/hook.rb` handles HTTP request as proxy. This is a hook script of
[matsumoto-r/mod_mruby](https://github.com/matsumoto-r/mod_mruby).
It forwards port which Docker container was assigned by Git-commit-id.

If there's no container which corresponds to Git-commit-id, `build_server` works to
build Docker image then runs it.
`build_server` sends build log so that you can confirm the status of build process
while waiting.

If there is another proccess to build and run container, `pool` locks to run other
process and waits until lock is over.

## Contributors

[Contributors](https://github.com/mookjp/pool/contributors)

