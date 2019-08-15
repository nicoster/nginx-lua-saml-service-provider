-- Copyright (C) by Hiroaki Nakamura (hnakamur)

local slaxml = require 'slaxml'
local setmetatable = setmetatable

local ins = require 'inspect'

local _M = { _VERSION = '0.1.0' }

local mt = { __index = _M }

function _M.new(self, config)
    return setmetatable({
        xmlsec_command = config.xmlsec_command,
        idp_cert_filename = config.idp_cert_filename
    }, mt)
end

function _M.read_and_base64decode_response(self)
    ngx.req.read_body()
    ngx.log(ngx.DEBUG, ngx.var.request_body)
    local args, err = ngx.req.get_post_args()
    ngx.log(ngx.DEBUG, ins(args))
    if err ~= nil then
       return nil, string.format("failed to get post args to read SAML response, err=%s", err)
    end

    local samlresp = args.SAMLResponse:gsub('\r\n', '')
    return ngx.decode_base64(samlresp)
end

function _M.extract_response_cert(self, response)
    local x509cert = response:match("<%a+:X509Certificate>(.*)</%a+:X509Certificate>")
    if x509cert then
        local tmpname = os.tmpname()
        local tmpf, err = assert(io.open(tmpname, 'w'))
        tmpf:write('-----BEGIN CERTIFICATE-----' .. x509cert .. '-----END CERTIFICATE-----\r\n')
        tmpf:close()
        return tmpname
    end
    return nil
end

function _M.verify_response(self, response)
    local tmpfilename = os.tmpname()
    local file, err = io.open(tmpfilename, "w")
    if file == nil or err ~= nil then
       return false, string.format("failed to open temporary file for writing SAML response, %s, err=%s", tmpfilename, err)
    end
    file:write(response)
    file:close()

    local embeded_x509 = self:extract_response_cert(response)

    local cmd = string.format("%s --verify --pubkey-cert-pem %s --id-attr:ID urn:oasis:names:tc:SAML:2.0:assertion:Assertion %s",
        self.xmlsec_command, embeded_x509 or self.idp_cert_filename, tmpfilename)
    ngx.log(ngx.DEBUG, cmd)
    local ok, status, code = os.execute(cmd)
    if code ~= 0 then
       return false, string.format("failed to verify SAML response, exitcode=%s", tostring(code))
    end

    local ok, err = os.remove(tmpfilename)
    if not ok then
       return false, string.format("failed to delete SAML response tmpfile, filename=%s, err=%s", tmpfilename, err)
    end
    return true
end

function _M.take_attributes_from_response(self, response_xml)
    local onAttributeElemStart = false
    local inAttributeElem = false
    local inAttributeValueElem = false
    local attrs = {}
    local attr_name = nil

    local handleStartElement = function(name, nsURI, nsPrefix)
        if nsPrefix == "saml" and name == "Attribute" then
            onAttributeElemStart = true
            inAttributeElem = true
        else
            onAttributeElemStart = false
        end
        if nsPrefix == "saml" and name == "AttributeValue" then
            inAttributeValueElem = true
        end
    end
    local handleAttribute = function(name, value, nsURI, nsPrefix)
        if onAttributeElemStart and name == "Name" then
            attr_name = value
        end
    end
    local handleCloesElement = function(name, nsURI)
        if nsPrefix == "saml" and name == "Attribute" then
            inAttributeElem = false
        end
        if nsPrefix == "saml" and name == "AttributeValue" then
            inAttributeValueElem = false
        end
    end

    local handleText = function(text)
        if inAttributeValueElem then
            attrs[attr_name] = text
        end
    end
    local parser = slaxml:parser{
        startElement = handleStartElement,
        attribute = handleAttribute,
        closeElement = handleCloseElement,
        text = handleText
    }
    parser:parse(response_xml, {stripWhitespace=true})
    return attrs
end

function _M.take_request_id_from_response(self, response_xml)
    local onResponseElement = false
    local request_id = nil

    local handleStartElement = function(name, nsURI, nsPrefix)
        if nsPrefix == "samlp" and name == "Response" then
            onResponseElement = true
        else
            onResponseElement = false
        end
    end
    local handleAttribute = function(name, value, nsURI, nsPrefix)
        if onResponseElement and name == "InResponseTo" then
            request_id = value
        end
    end
    local parser = slaxml:parser{
        startElement = handleStartElement,
        attribute = handleAttribute
    }
    parser:parse(response_xml, {stripWhitespace=true})
    return request_id
end

return _M
