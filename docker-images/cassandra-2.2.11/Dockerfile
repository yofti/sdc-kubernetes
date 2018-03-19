FROM cassandra:2.2.11
MAINTAINER yofti <yofti@sysdig.com>


RUN echo 'deb http://ftp.debian.org/debian jessie-backports main' >> /etc/apt/sources.list
RUN apt-get update && \
	apt-get -y install dnsutils && \
	apt-get install -y -t jessie-backports openjdk-8-jdk-headless ca-certificates-java && \
	unlink /etc/alternatives/java && \
	ln -s /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/bin/java  /etc/alternatives/java && \
    	apt-get clean && \
    	mkdir -p /opt/cassandra/certs /opt/cassandra/keystores && \
	rm -rf /var/lib/apt/lists/*

COPY cassandra.yaml /etc/cassandra/
COPY cassandra-env.sh /etc/cassandra/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY limits.conf /etc/security/

#ENTRYPOINT ["/docker-entrypoint.sh"]
