FROM centos:centos6
MAINTAINER mookjp

WORKDIR /tmp

RUN rpm -ivh http://ftp-srv2.kddilabs.jp/Linux/distributions/fedora/epel/6/x86_64/epel-release-6-8.noarch.rpm

RUN export PATH=$PATH:/usr/local/bin

# Set time
RUN cp /usr/share/zoneinfo/Japan /etc/localtime

# Install required packages
RUN yum install -y bison
RUN yum install -y gcc-c++
RUN yum install -y docker-io
RUN yum install -y git
RUN yum install -y glibc-headers
RUN yum install -y hiredis-devel
RUN yum install -y httpd
RUN yum install -y httpd-devel
RUN yum install -y libyaml-devel
RUN yum install -y openssl-devel
RUN yum install -y readline
RUN yum install -y readline-devel
RUN yum install -y supervisor
RUN yum install -y tar
RUN yum install -y zlib
RUN yum install -y zlib-devel


# Install Ruby
RUN git clone https://github.com/sstephenson/ruby-build.git /opt/ruby-build
RUN chmod u+x /opt/ruby-build/install.sh
RUN /opt/ruby-build/install.sh
RUN /usr/local/bin/ruby-build 2.1.2 /opt/ruby-2.1.2
RUN ln -s /opt/ruby-2.1.2/bin/ruby /usr/local/bin/ruby

# Install mod_mruby
RUN git clone https://github.com/matsumoto-r/mod_mruby.git /tmp/mod_mruby
WORKDIR /tmp/mod_mruby
RUN chmod u+x ./build.sh
RUN ./build.sh
RUN make install
WORKDIR /tmp

# Add PATH
RUN rm /usr/local/bin/ruby
RUN find /opt/ruby-2.1.2/bin/* | xargs -I {} ln -s {} /usr/local/bin

# Install required gems
RUN /usr/local/bin/gem install git --no-document
RUN /usr/local/bin/gem install em-websocket --no-document

# hostname settings
ADD provisioning/network /etc/sysconfig/network
ADD provisioning/hosts /etc/sysconfig/hosts

# Apache settings
ADD provisioning/httpd.conf /etc/httpd/conf/httpd.conf
ADD provisioning/mruby.conf /etc/httpd/conf.d/mruby.conf

# Add apache to docker group to access docker sockfile
RUN usermod -G docker apache

# Add supervisor configuration file
ADD provisioning/supervisord.conf /etc/supervisord.conf

ADD builder /app/builder
ADD handlers /app/handlers

# Add log directories
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /var/log/builder
RUN mkdir -p /app/images
RUN touch /app/images/ids

EXPOSE 80 8080

CMD \
    chown root:docker /var/run/docker.sock && \
    chmod 775 /var/run/docker.sock && \
    service httpd start && \
    service supervisord start && \
    tailf /var/log/httpd/error_log

