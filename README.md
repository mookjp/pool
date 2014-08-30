🐳 pool 🐳
===

The simplest proxy service to access your Dockernized webapps by Git commit-id.

You can build and run your web application as a Docker container just to access
`http://<git-commit-id>.pool.dev` for example.

<p align="center">
<img src="https://raw.githubusercontent.com/wiki/mookjp/pool/images/architecture.png" width="600"/>
</p>


## Requirements

### Vagrant plugin

Need to install [vagrant dns plugin](https://github.com/BerlinVagrant/vagrant-dns). Just run:

> $ vagrant plugin install vagrant-dns

## Setup

Set the configration for dns first:

> $ vagrant dns --install

> $ vagrant dns --start

then run:

> $ vagrant up

Vagrantfile has dns settings for this development environment.
You can access your Docker container just to go `http://<git-commit-id>.pool.dev`.

## How it works

This proxy accesses your Git repository with commit id.
Then checkout it with Dockerfile. Dockerfile should be on the root of the
repository. After checkout files, the container will be built by the Dockerfile
and port is linked with front automatically. All you can do is just to access
`http://<git-commit-id>.pool.dev`.

`handlers/hook.rb` is the only file to handle this. This is a hook script of
[matsumoto-r/mod_mruby](https://github.com/matsumoto-r/mod_mruby).
If you want to check it with your own Docker web-app project, you can rewrite
Git repository url inside `handlers/hook.rb`.

## Contributors:

Patches contributed by [gread developers](https://github.com/mookjp/pool/contributors).

