FROM redis
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update \
  && apt-get -y upgrade && apt-get install -y gcc make
RUN apt-get -y install wget zlib1g-dev libssl-dev libreadline-dev libgdbm-dev openssl iputils-ping telnet net-tools dnsutils

RUN set -x; mkdir RUBY; \
cd RUBY;  \
wget https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.0.tar.gz; \
tar xvfz ruby-2.3.0.tar.gz; \
cd ruby-2.3.0; \
./configure; \
make; \
make install

RUN gem install bundler \
  && gem install redis 

 RUN apt-get -y remove gcc make  && apt-get -y autoremove \
  && apt-get -y clean
RUN wget -O /usr/local/bin/redis-trib http://download.redis.io/redis-stable/src/redis-trib.rb
RUN chmod 755 /usr/local/bin/redis-trib
CMD redis-server
