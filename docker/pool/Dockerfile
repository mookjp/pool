FROM ainoya/apache-mod-mruby
MAINTAINER mookjp

WORKDIR /tmp

RUN export PATH=$PATH:/usr/local/bin

# Set time
RUN cp /usr/share/zoneinfo/Japan /etc/localtime

# Install required packages
RUN yum install -y docker-io
RUN yum install -y git
RUN yum install -y supervisor
RUN yum install -y cronie
# For build-screen
RUN yum install -y npm
RUN yum install -y bzip2

# Install required gems
RUN /usr/local/bin/gem install --no-document bundler

# hostname settings
ADD provisioning/network /etc/sysconfig/network
ADD provisioning/hosts /etc/sysconfig/hosts

# Add Apache settings
ADD provisioning/httpd.conf /etc/httpd/conf/httpd.conf
ADD provisioning/mruby.conf /etc/httpd/conf.d/mruby.conf

# Add supervisor configuration file
ADD provisioning/supervisord.conf /etc/supervisord.conf

# Add container-limitation configuration gile
ADD provisioning/cron/limit_containers /etc/cron.d/limit_containers

# Install build-srver
# Use cache if Gemfile.lock is not updated
ADD builder /tmp/builder-tmp
ADD builder/Gemfile.lock /tmp/builder/Gemfile.lock
WORKDIR /tmp/builder
RUN cp /tmp/builder-tmp/Gemfile /tmp/builder
RUN cp /tmp/builder-tmp/builder.gemspec /tmp/builder
RUN /opt/ruby-2.1.2/bin/bundle install --path=vendor/bundle
RUN cp -a /tmp/builder-tmp /tmp/builder
# Test builder
RUN /opt/ruby-2.1.2/bin/bundle exec rake spec
RUN /usr/local/bin/gem build builder.gemspec
RUN /usr/local/bin/gem install builder-0.0.1.gem

# Add mod_mruby handler to manage request
ADD handlers /app/handlers

# Install build-screen
RUN mkdir -p /app/handlers/resources
# Use cache if packages.json is not updated
ADD build-screen/package.json /tmp/build-screen/package.json
WORKDIR /tmp/build-screen
RUN npm install
# Use cache if bower.json is not updated
ADD build-screen/bower.json /tmp/build-screen/bower.json
RUN git config --global url.https://.insteadOf git://
RUN $(npm bin)/bower --allow-root install
ADD build-screen /tmp/build-screen-tmp
RUN cp -nr /tmp/build-screen-tmp/* /tmp/build-screen
RUN $(npm bin)/grunt build
RUN mv /tmp/build-screen/dist /app/handlers/resources/build-screen

# Add util scripts for handling containers
ADD scripts /app/scripts
RUN chmod +x /app/scripts/starter
RUN chmod +x /app/scripts/limit_containers

# Add log directories
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /var/log/builder
RUN mkdir -p /app/images
RUN touch /app/images/ids

# Add apache to pool and docker group to access /app
# as hook.rb has to access application's repository in it
# and to access docker sock file
RUN groupadd pool
RUN usermod -G docker,pool apache
RUN chgrp --recursive pool /app
RUN chmod --recursive g+rwx /app

# Set target preview repository
ENV PREVIEW_REPOSITORY_URL https://github.com/mookjp/flaskapp.git
ENV MAX_CONTAINERS 10
ENV POOL_BASE_DOMAIN pool.dev

EXPOSE 80 8080

CMD \
    /app/scripts/starter && \
    tail -F /var/log/httpd/error_log

