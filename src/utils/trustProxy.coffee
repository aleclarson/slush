
proxyaddr = require "proxy-addr"

module.exports = (value) ->
  return value if typeof value is "function"

  # Support plain true/false
  if value is yes
    return emptyFunction.thatReturnsTrue

  # Support trusting 'hop count'
  if typeof value is "number"
    return (a, i) -> i < value

  # Support comma-separated values
  if typeof value is "string"
    value = value.split /\s*,\s*/

  return proxyaddr.compile value or []
