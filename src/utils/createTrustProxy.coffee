emptyFunction = require "emptyFunction"
proxyaddr = require "proxy-addr"

createTrustProxy = (value) ->
  value_t = typeof value

  if value_t is "function"
    return value

  if value is true
    return emptyFunction.thatReturnsTrue

  if value is false
    return emptyFunction.thatReturnsFalse

  # Support trusting 'hop count'
  if value_t is "number"
    return (a, i) -> i < value

  # Support comma-separated values
  if value_t is "string"
    value = value.split /\s*,\s*/

  return proxyaddr.compile value or []

module.exports = createTrustProxy
