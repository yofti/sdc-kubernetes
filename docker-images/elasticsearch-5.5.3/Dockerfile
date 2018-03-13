FROM docker.elastic.co/elasticsearch/elasticsearch:5.5.3

WORKDIR /usr/share/elasticsearch

USER root

#RUN yum -y update && yum clean all
#RUN yum -y install epel-release 
#RUN yum -y install telnet htop atop net-tools iotop && yum clean all
#RUN rm -rf /var/cache/yum


# copying custom-entrypoint and configuration (elasticsearch.yml, log4j2.properties)
# to their respective directories in /usr/share/elasticsearch (already the WORKDIR)
COPY docker-entrypoint.sh /
COPY elasticsearch.yml config/
COPY log4j2.properties config/
COPY jvm.options config/
COPY limits.conf /etc/security/limits.conf
COPY 20-nproc.conf /etc/security/limits.d/20-nproc.conf
COPY login /etc/pam.d/login
COPY su /etc/pam.d/su

# assuring "elasticsearch" user have appropriate access to configuration and custom-entrypoint
# make sure custom-entrypoint is executable
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml config/log4j2.properties
RUN bin/elasticsearch-plugin remove x-pack 
RUN chown root /etc/security/limits.conf && chmod 644 /etc/security/limits.conf
RUN chown root /etc/pam.d/login && chmod 644 /etc/pam.d/login
RUN chown root /etc/pam.d/su && chmod 644 /etc/pam.d/su

ENTRYPOINT ["/docker-entrypoint.sh"]

