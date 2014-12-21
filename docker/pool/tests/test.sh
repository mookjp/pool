#!/bin/sh -xe

export PATH=$PATH:/opt/ruby-2.1.2/bin/ 

yum -y install libxslt-devel libxml2-devel

bundle config build.nokogiri --use-system-libraries

bundle install

bundle exec rspec
