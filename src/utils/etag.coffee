
isValid = require "isValid"

exports.compile = (value) ->

  if isValid value, "function"
    return value

  if value is no
    return

  if value is yes
    return compile yes

  if value is "strong"
    return compile no

  if value is "weak"
    return compile yes

  throw TypeError "Invalid value for 'etag' setting: " + value

compile = (weak) ->
  etag = require "etag"
  options = {weak}
  return (body, encoding) ->
    unless Buffer.isBuffer body
      body = new Buffer body, encoding
    return etag buffer, options
