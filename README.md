# Squid4 HTTP/HTTPS Proxy with RADIUS Auth

This dockerfile builds a Squid 4 instance and includes all the necessary
tooling to run it as a MITM (man-in-the-middle) SSL proxy.

The resulting docker image uses the following configuration environment
variables:

 * `HTTP_PORT`
    Default: `3128`
 * `HTTPS_PORT`
    Default: `3129`
 * `HTTPS_ENABLED`
    Option to enable or disable HTTPS support. Default: `false`
 * `HTTPS_CERT`
    Required for HTTPS. Path to Fullchain Cert file for HTTPS port.
 * `HTTPS_KEY`
    Required for HTTPS. Path to Private Key file for HTTPS port.
 * `VISIBLE_HOSTNAME`
    Default: `docker-squid4`
 * `ACCESS_LOG`
    Default: `stdio:/dev/stdout combined`
 * `ACCESS_LOG`
    Default: `/dev/stderr`
 * `DEBUG_OPTIONS`
    Default: `ALL,1`
    More information on debugging section and level numbers can be found here: [Debugging via cache.log](http://etutorials.org/Server+Administration/Squid.+The+definitive+guide/Chapter+16.+Debugging+and+Troubleshooting/16.2+Debugging+via+cache.log/)
 * `AUTH_CHILDREN`
   Default: `5000`
 * `PCONN_TIMEOUT`
   Default: `2 minutes`
   Squid will close persistent connections if they are idle for this amount of time. Persistent connections will be disabled entirely if this option is set to a value less than 10 seconds.
 * `CONNECT_TIMEOUT`
   Default: `2 minutes`
   This option specifies the timeout for how long Squid should wait for the connection to complete.
 * `REQUEST_TIMEOUT`
   Default: `5 minutes`
   Squid to wait for an HTTP request after initial connection establishment.
 * `AUTH_REALM`
   Default: `Restricted Area`
 * `RADIUS_ENABLE`
   Default: `false`
   If set to `true` then squid will be configured to connect and perform basic auth against a RADIUS server specified in the variables below (make sure all variables starting with `RADIUS_` are set).
 * `RADIUS_SERVER`
   Default: ""
 * `RADIUS_PORT`
   Default: `1812`
 * `RADIUS_SECRET`
   Default: ""
 * `CUSTOM_ACLS`
   Default: 
   ```
   acl auth_users proxy_auth REQUIRED
   http_access allow all auth_users
   ```
   Custom set of ACLs to be added (separated by newlines) before the final `http_access deny all` rule. 
   Note: setting this variable replaces the default auth ACL.
 * `EXTRA_CONFIGx`
   Extra non-specific configuration lines to be appended after the main body of
   the configuration file. This is a good place for custom ACL parameters.
 * `CONFIG_DISABLE`
   Default `false`
   If set to `true` then squid configuration templating is disabled entirely, allowing
   bind mounting the configuration file in manually instead.

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


# Credits
Thank you @wrouesnel! This image was based off of your [wrouesnel/docker-squid4](https://hub.docker.com/r/wrouesnel/docker-squid4) docker image. 