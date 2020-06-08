# Squid4 HTTP/HTTPS Proxy with RADIUS Auth

This dockerfile builds a Squid 4 instance and includes all the necessary
tooling to run it as a MITM (man-in-the-middle) SSL proxy.

The resulting docker image uses the following configuration environment
variables:

 * `HTTP_PORT`
    Default: `3128`
 * `HTTPS_PORT`
    Default: `3129`
 * `HTTPS_CERT`
    Required. Path to Fullchain Cert file for HTTPS port.
 * `HTTPS_KEY`
    Required. Path to Private Key file for HTTPS port.
 * `VISIBLE_HOSTNAME`
    Default: `docker-squid4`
 * `ACCESS_LOG`
    Default: `stdio:/dev/stdout combined`
 * `AUTH_CHILDREN`
   Default: `5000`
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