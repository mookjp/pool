🐳 pool 🐳
===

The simplest proxy service to access your Dockerized webapps by Git commit-id.

You can build and run your web application as a Docker container just to access
`http://<git-commit-id>.pool.dev` for example.

<p align="center">
<img src="https://raw.githubusercontent.com/wiki/mookjp/pool/images/architecture.png" width="600"/>
</p>

## Requirements

### Vagrant

Pool needs [Vagrant](https://www.vagrantup.com/).

### Vagrant plugin

You also need to install [vagrant dns plugin](https://github.com/BerlinVagrant/vagrant-dns). Just run after vagrant was installed:

> $ vagrant plugin install vagrant-dns

## Quick start

Launching web app with pool is handy. We just run the following two steps.

### Launch Vagrant box

Set the configration for dns first:

> $ vagrant dns --install

> $ vagrant dns --start

then run:

> $ vagrant up

### Access web application

To watch the web application with pool, you just access `http://<git-commit-id>.pool.dev` with your **browser**.

In the default setting, pool is configured for the web application maintained in the [mookjp/flaskapp](https://github.com/mookjp/flaskapp) repository.
You can see the flask app (which just outputs 'hello world') just visiting `http://c8f48c60088bbae0d0fb25ed5fd04f4442b58617.pool.dev/` or `http://master.pool.dev/`.

## How it works

This proxy accesses your Git repository with commit id.
Then checkout it with Dockerfile. Dockerfile should be on the root of the
repository. After checkout files, the container will be built by the Dockerfile
and port is linked with front automatically. All you can do is just to access
`http://<git-commit-id>.pool.dev`.

pool consists of two module; proxy hook and container builder.

`handlers/hook.rb` handles HTTP request as proxy. This is a hook script of
[matsumoto-r/mod_mruby](https://github.com/matsumoto-r/mod_mruby).
It forwards port which Docker container was assigned by Git-commit-id.

If there's no container which corresponds to Git-commit-id, `build_server.rb` works to
build Docker image then runs it.
`build_server.rb` sends build log so that you can confirm the status of build process
while waiting.

## Contributors:

Patches contributed by [great developers](https://github.com/mookjp/pool/contributors).

