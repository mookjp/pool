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
ADD scripts /app/scripts

RUN chmod +x /app/scripts/starter

# Add log directories
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /var/log/builder
RUN mkdir -p /app/images
RUN touch /app/images/ids

# Set target preview repository
ENV PREVIEW_REPOSITORY_URL https://github.com/mookjp/flaskapp.git

EXPOSE 80 8080

CMD \
    /app/scripts/starter && \
    tailf /var/log/httpd/error_log

