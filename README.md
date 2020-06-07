# Squid4 with SSL proxying

This dockerfile builds a Squid 4 instance and includes all the necessary
tooling to run it as a MITM (man-in-the-middle) SSL proxy.

There's a number of reasons to do this - the big one being optimizing caching
and delivery of objects during docker builds which might be downloading them
from SSL protected endpoints.

It will require you to generate your own CA and set it as trusted.

The resulting docker image uses the following configuration environment
variables:

 * `HTTP_PORT`
    Default: `3128`
 * `HTTPS_PORT`
   Default: `3129`
 * `VISIBLE_HOSTNAME`
    Default: `docker-squid4`
 * `EXTRA_CONFIGx`
   Extra non-specific configuration lines to be appended after the main body of
   the configuration file. This is a good place for custom ACL parameters.
 * `CONFIG_DISABLE`
   Default `false`
   If set to `true` then squid configuration templating is disabled entirely, allowing
   bind mounting the configuration file in manually instead.
 * `TLS_OPTIONS`
   Default `NO_SSLv3,NO_TLSv1`
   Allow overriding the default tls_outgoing_options supplied to OpenSSL. These
   are safe defaults, but if you're in a really broken environment might not be
   usable.

# Proxychains
By default squid in SSL MITM mode treats `cache_peer` entries quite differently.
Because squid unwraps the CONNECT statement when bumping an SSL connection, but
does not rewrap it when communicating with peers, it requires all peers to connect
with SSL as well. This breaks compatibility with simple minded proxies.

To work around this, proxychains-ng (`proxychains4` internally) is built and
included in this image. If you need to use an upstream proxy with a MITM
squid4, you should launch the image in proxychains mode which intercepts squids
direct outbound connections and redirects them via CONNECT requests. This also
adds SOCKS4 and SOCKS5 proxy support if so desired.

proxychains is configured with the following environment variables. As with the
others above, `CONFIG_DISABLE` prevents overwriting templated files.

 * `PROXYCHAIN`
    Default none. If set to `yes` then squid will be launched with proxychains.
    You should specify some proxies when doing this.
 * `PROXYCHAIN_PROXYx`
    Upstream proxies to be passed to the proxy chan config file. The suffix (`x`)
    determines the order in which they are templated into the configuration file.
    The format is a space separated string like "http 127.0.0.1 3129"
 * `PROXYCHAIN_TYPE`
    Default `strict_chain`. Can be `strict_chain` or `dynamic_chain` sensibly
    within this image. In `strict_chain` mode, all proxies must be up. In
    `dynamic_chain` mode proxies are used in order, but skipped if down.
    Disable configuration and bind a configuration file to /etc/proxychains.conf
    if you need more flexibility.
 * `PROXYCHAIN_DNS`
   Default none. When set to `yes`, turns on the `proxy_dns` option for Proxychains.

# DNS-over-HTTPS
In some corporate environments, its not possible to get reliable DNS outbound
service and `proxychains-ng`'s DNS support won't be able to provide for Squid4
to actually work. To address this, configuration is included to setup and use
DNS-over-HTTPS.

The idea of the DNS-over-HTTPS client is that it will use your local proxy and
network access to provide DNS service to Squid4.

* `DNS_OVER_HTTPS`
  Default `no`. If `yes` then enables and starts the DNS_OVER_HTTPS service.
* `DNS_OVER_HTTPS_LISTEN_ADDR`
  Default `127.0.0.153:53`. Squid doesn't support changing the port, so keep
  this in mind.
* `DNS_OVER_HTTPS_SERVER`
  Default `https://dns.google.com/resolve`. AFAIK there's no other options for
  this at the moment.
* `DNS_OVER_HTTPS_NO_PROXY`
  Default ``. List of DNS suffixes to *not* ever proxy via DNS_OVER_HTTPS.
* `DNS_OVER_HTTPS_PREFIX_SERVER`
  Default ``. Normal DNS server to try resolving first against.
* `DNS_OVER_HTTPS_SUFFIX_SERVER`
  Default ``. Normal DNS server to try resolving last against.

Since the DNS-over-HTTPS daemon is a separate Go binary, you may also need to
specify your internal proxy as an upstream to allow it to contact the HTTPS
DNS server - do this by passing the standard `http_proxy` and `https_proxy`
parameters. Most likely these will be the same as your `PROXYCHAIN_PROXYx`
directives (and probably only the 1).

# Example Usage
The following command line will get you up and running quickly. It presumes
you've generated a suitable CA certificate and are intending to use the proxy
as a local MITM on your machine:
```
sudo mkdir -p /srv/squid/cache
docker run -it -p 3128:127.0.0.1:3128 --rm \
    -v /srv/squid/cache:/var/cache/squid4 \
    -v /etc/ssl/certs:/etc/ssl/certs:ro \ 
    -v /etc/ssl/private/local_mitm.pem:/local-mitm.pem:ro \
    -v /etc/ssl/certs/local_mitm.pem:/local-mitm.crt:ro \
    -e MITM_CERT=/local-mitm.crt \
    -e MITM_KEY=/local-mitm.pem \
    -e MITM_PROXY=yes \
    squid
```

Note that it doesn't really matter where we mount the certificate - the image
launch script makes a copy as root to avoid messing with permissions anyway.
