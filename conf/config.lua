
local SP_URL = 'https://local.zoomdev.us/sso'
return {
    key_attribute_name = "EmailAddress",
    redirect = {
        url_after_login = "/",
        url_after_logout = "/"
    },
    request = {
        idp_dest_url = "https://idp.ssocircle.com:443/sso/SSORedirect/metaAlias/publicidp",
        sp_entity_id = SP_URL,
        sp_saml_finish_url = SP_URL .. "/finish-login",
        urls_before_login = {
            dict_name = "sso_redirect_urls",
            expire_seconds = 180
        }
    },
    response = {
        xmlsec_command = "/usr/local/bin/xmlsec1",
        idp_cert_filename = ngx.config.prefix() .. "/idp.crt"
    },
    session = {
        cookie = {
            name = "sso_session_id",
            path = "/",
            secure = true
        },
        store = {
            dict_name = "sso_sessions",
            expire_seconds = 600
        }
    }
}
