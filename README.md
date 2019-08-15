ngxlua-saml-sp
===============================

A simple SAML service provider library for [openresty](https://github.com/openresty/lua-nginx-module).

Thanks [@hnakamur](https://github.com/hnakamur) for this sample project. I made some modification to integrate with [SSOCircle](https://ssocircle.com).

I was trying to understand how SAML exactly works. Even though I've read lots of documents regarding this topic, I still feel unfamiliar with terms like IdP, SP, SAML Request/Assertion. The best way to learn something is to implement it from scratch. Having a sample to start with makes this journey less painful.

The goal here is to minimize the efforts for others to integrate with SSOCircle.


## Dependencies

* [hamishforbes/lua-ffi-zlib](https://github.com/hamishforbes/lua-ffi-zlib)
* [bungle/lua-resty-template](https://github.com/bungle/lua-resty-template)
* [cloudflare/lua-resty-cookie] Lua library for HTTP cookie manipulations for OpenResty/ngx_lua
* `xmlsec1` command with OpenSSL support in [XML Security Library](https://www.aleksey.com/xmlsec/)

To make it easier to use, I imported the following dependencies into the source code:
* [Phrogz/SLAXML: SAX-like streaming XML parser for Lua](https://github.com/Phrogz/SLAXML)
* [hnakamur/nginx-lua-session](https://github.com/hnakamur/nginx-lua-session)

On CentOS7, you can install `xmlsec1` command with OpenSSL support with the following command:

```
sudo yum install xmlsec1 xmlsec1-openssl
```

## Changes
* Restructure the folder

    to make it easier to run as a standalone OpenResty application, the directory has been restructured. You may issue `make run` to run it with minor changes to Makefile.

* xmlsec verification command line

    as SSOcircle use a different SAML assertion, the xmlsec command like has been changed to `/usr/local/bin/xmlsec1 --verify --pubkey-cert-pem $CERT_FILE --id-attr:ID urn:oasis:names:tc:SAML:2.0:assertion:Assertion $SAML_RESP`

    the `CERT_FILE` is extracted from SAML Assertion. and the XML namespace is changed as shown above.

## Configuration

* `SP_URL`

    you need to change this url to something unique. as this url is part of the sp_entity_id. one approach is to add an entry into your /etc/hosts file, and then use the alias in the url. 

* `idp_dest_url`

    this is is configured for SSOCircle. No need to change.

* `idp_cert_filename`

    this config isn't really used during verifying the SAML assertion as SSOCircle returns an assertion that is signed with a self-signed certificate which is embedded in the assertion XML.

* `key_attribute_name`

    this is to specify which key is mandatory for a successful SAML assertion. It's been set to 'EmailAddress' for SSOCircle.

* SAML Metadata

    we need to specify a SAML Metadata in the your account profile in SSOCircle. you can use this [online tool](https://www.ssocircle.com/en/idp-tips-tricks/build-your-own-metadata/) to create a meta file. the `entityID` is `sp_entity_id` in the config.lua, and `ACS URL` is `sp_saml_finish_url`. If this is not configurated correctly, you should come across "invalid issuer error".

## Caveats

Generally speaking you should avoid blocking I/O in programs with [openresty/lua-nginx-module](https://github.com/openresty/lua-nginx-module).
However, this library contains blocking I/O when a user finished logging in:

* Save a SAML response to a temporary file using Lua's `os.tmpname`, `io.open`, and `io.write`.
* Run the command `xmlsec` with Lua's `os.execute`.

For the latter, I found [jprjr/lua-resty-exec: Run external programs in OpenResty without spawning a shell or blocking](https://github.com/jprjr/lua-resty-exec), but I haven't tried it yet. With this, you need to manage a socket file. But I like to avoid it this time for a simpler setup.

For the best performance, I would rather call functions in [XML Security Library](https://www.aleksey.com/xmlsec/) using LuaJIT FFI.

In `apps/xmlsec.c`, the function `xmlSecAppVerifyFile` calls `xmlSecAppXmlDataCreate`, then `xmlSecParseFile`. If you use `xmlSecParseMemoryExt` instead, you don't need to save the SAML response to a temporary file. However a lot of efforts for this implementation, and I choose not to do this now.

Reading the ID provider's certificate will still remain as a blocking I/O with the above FFI calls.
I just skimmed at xmlsec source code, so this could be wrong.

However, for my use case now, the site traffic is very low, and verifying the SAML response is only needed when users finish logging in, so I don't think it is a problem using blocking I/O for saving a temporary file and running a command synchronously.
