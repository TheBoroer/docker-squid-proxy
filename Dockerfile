ARG DOCKER_PREFIX=
FROM ${DOCKER_PREFIX}ubuntu:jammy

ARG SQUID_VERSION=6.13
ARG TRUST_CERT=
ARG DEBIAN_FRONTEND=noninteractive
ARG PROXY_USER=proxy

ENV TZ=America/Toronto

RUN if [ ! -z "$TRUST_CERT" ]; then \
    echo "$TRUST_CERT" > /usr/local/share/ca-certificates/build-trust.crt ; \
    update-ca-certificates ; \
    fi

# Normalize apt sources
RUN cat /etc/apt/sources.list | grep -v '^#' | sed /^$/d | sort | uniq > sources.tmp.1 && \
    cat /etc/apt/sources.list | sed s/deb\ /deb-src\ /g | grep -v '^#' | sed /^$/d | sort | uniq > sources.tmp.2 && \
    cat sources.tmp.1 sources.tmp.2 > /etc/apt/sources.list && \
    rm -f sources.tmp.1 sources.tmp.2

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get build-dep -y squid && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget tar xz-utils libssl-dev

# TODO: verify the squid download with the signing key
# 6.12 and under: https://www.squid-cache.org/Versions/v${SQUID_VERSION%%.*}/squid-$SQUID_VERSION.tar.xz
# 6.13 and up: https://github.com/squid-cache/squid/releases/download/SQUID_${SQUID_VERSION//./_}/squid-$SQUID_VERSION.tar.xz
RUN mkdir /src \
    && cd /src \
    && wget "https://github.com/squid-cache/squid/releases/download/SQUID_$(echo ${SQUID_VERSION} | tr '.' '_')/squid-$SQUID_VERSION.tar.xz" \
    && mkdir squid \
    && tar -C squid --strip-components=1 -xvf squid-$SQUID_VERSION.tar.xz

RUN cd /src/squid && \
    ./configure \
    --prefix=/usr \
    --datadir=/usr/share/squid \
    --sysconfdir=/etc/squid \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --disable-maintainer-mode \
    --disable-dependency-tracking \
    --enable-inline \
    --enable-async-io=8 \
    --enable-storeio="ufs,aufs,coss,diskd,null" \
    --enable-removal-policies="lru,heap" \
    --enable-poll \
    --enable-delay-pools \
    --enable-cache-digests \
    --enable-snmp \
    --enable-htcp \
    --enable-select \
    --enable-carp \
    --with-large-files \
    --enable-underscores \
    --enable-icap-client \
    --enable-auth="yes" \
    --enable-auth-basic="LDAP,NCSA,PAM,SASL,SMB,getpwnam,RADIUS,DB" \
    --enable-auth-digest="LDAP,file" \
    --enable-external-acl-helpers="file_userip,LDAP_group,session,unix_group,wbinfo_group,SQL_session" \
    --with-filedescriptors=65536 \
    --enable-epoll \
    --enable-linux-netfilter \
    --enable-follow-x-forwarded-for \
    --enable-url-rewrite-helpers="fake" \
    --enable-eui \
    --enable-esi \
    --enable-icmp \
    --enable-zph-qos \
    --with-openssl \
    --enable-ssl \
    --enable-ssl-crtd \ 
    --disable-translation \
    --with-swapdir=/var/spool/squid \
    --with-logdir=/var/log/squid \
    --with-pidfile=/var/run/squid.pid \
    --with-filedescriptors=65536 \
    --with-large-files \
    --with-default-user=proxy \
    --disable-arch-native

RUN cd /src/squid && \
    make -j$(nproc) && \
    make install

# Download p2cli dependency
RUN wget -O /usr/local/bin/p2 \
    https://github.com/wrouesnel/p2cli/releases/download/r1/p2 && \
    chmod +x /usr/local/bin/p2

# Clone and build proxychains-ng for SSL upstream proxying
ARG PROXYCHAINS_COMMITTISH=7a233fb1f05bcbf3d7f5c91658932261de1e13cb

# Install required tools
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y git net-tools nano curl python3 python3-pip

RUN git clone https://github.com/rofl0r/proxychains-ng.git /src/proxychains-ng && \
    cd /src/proxychains-ng && \
    git checkout $PROXYCHAINS_COMMITTISH && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j$(nproc) && make install

ARG URL_DOH=https://github.com/wrouesnel/dns-over-https-proxy/releases/download/v0.0.2/dns-over-https-proxy_v0.0.2_linux-amd64.tar.gz
RUN wget -O /tmp/doh.tgz \
    $URL_DOH && \
    tar -xvvf /tmp/doh.tgz --strip-components=1 -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/dns-over-https-proxy

COPY custom/Pipfile /Pipfile
COPY custom/error_pages /etc/squid/error_pages
COPY custom/error_pages.css /etc/squid/error_pages.css
COPY custom/radius_auth.conf.p2 /radius_auth.conf.p2
COPY custom/squid.conf.p2 /squid.conf.p2

COPY squid.bsh /squid.bsh
RUN sed -i 's/\r//' /squid.bsh
RUN chmod +x /squid.bsh

# Environment Configuration
ENV HTTP_PORT=3128 \
    HTTPS_PORT=3129 \
    PROXY_USER="$PROXY_USER" \
    VISIBLE_HOSTNAME=docker-squid \
    DNS_OVER_HTTPS_LISTEN_ADDR="127.0.0.153:53" \
    DNS_OVER_HTTPS_SERVER="https://dns.google.com/resolve" \
    DNS_OVER_HTTPS_NO_FALLTHROUGH="" \
    DNS_OVER_HTTPS_FALLTHROUGH_STATUSES=NXDOMAIN \
    DNS_OVER_HTTPS_PREFIX_SERVER= \
    DNS_OVER_HTTPS_SUFFIX_SERVER= \
    PIPENV_VENV_IN_PROJECT=1

# Setup the Python environment
RUN mkdir /bin/.local && chmod 777 /bin/.local
RUN pip3 install pipenv

# Install python packages to venv
RUN pipenv install
# Also install them to system as the proxy user
RUN su $PROXY_USER -s /bin/bash -c "pipenv install --system"

EXPOSE 3128
EXPOSE 3129

ENTRYPOINT [ "/squid.bsh" ]
