
exports.compile = (value) ->

  if typeof value is "function"
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
    return etag body, options
