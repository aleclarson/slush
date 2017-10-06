
emptyFunction = require "emptyFunction"
proxyaddr = require "proxy-addr"
isValid = require "isValid"

createTrustProxy = (value) ->

  if typeof value is "function"
    return value

  if value is true
    return emptyFunction.thatReturnsTrue

  if value is false
    return emptyFunction.thatReturnsFalse

  # Support trusting 'hop count'
  if isValid value, "number"
    return (a, i) -> i < value

  # Support comma-separated values
  if isValid value, "string"
    value = value.split /\s*,\s*/

  return proxyaddr.compile value or []

module.exports = createTrustProxy
