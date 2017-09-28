
Promise = require "Promise"
isValid = require "isValid"
valido = require "valido"
Type = require "Type"

readBody = require "./utils/readBody"

emptyArray = []
matchAll = /.*/g

type = Type "Route"

type.defineValues

  _regex: null

  _authorize: null

type.defineMethods

  match: (pattern) ->
    if isValid pattern, "regexp"
      pattern.params = emptyArray
      @_regex = pattern
    else if isValid pattern, "string"
      @_regex = createRegex pattern
    else
      throw TypeError "Expected a String or RegExp!"
    return

  authorize: (authorize) ->
    @_authorize = authorize
    return

  _build: (responder, method) ->
    regex = @_regex or matchAll
    route = @_wrapResponder responder

    if authorize = @_authorize
      responder = route
      route = (req, res) ->
        if authorize(req) is no
          return Promise.resolve 403
        return responder req, res

    return (req) ->
      return if req.method isnt method
      return route if matchRegex req, regex

  _wrapResponder: (responder) ->

    if isValid @query, "object"
      queryTypes = @query

      Object.keys(queryTypes).forEach (key) ->
        type = queryTypes[key]
        if type is Number
          queryTypes[key] = stringToNumber
        else if type is Boolean
          queryTypes[key] = stringToBoolean
        return

      return (req, res) -> Promise.try ->
        return error if error = validateTypes req.query, queryTypes
        return responder.call req, req.query, res

    if @body is yes
      return (req, res) ->
        readBody(req).then ->
          return Error "Missing body" unless req.body
          return responder.call req, req.body, res

    if isValid @body, "object"
      bodyTypes = @body
      return (req, res) ->
        readBody(req).then ->
          return Error "Missing body" unless req.body
          return req.json (body) ->
            return error if error = validateTypes body, bodyTypes
            return responder.call req, body, res

    return (req, res) ->
      Promise.try ->
        responder.call req, res

module.exports = type.build()

#
# Helpers
#

stringToNumber = (query, key) ->
  value = parseInt query[key]

  if isNaN value
    return Error "Expected '#{key}' to be a Number"

  query[key] = value
  return

stringToBoolean = (query, key) ->
  value = query[key]

  if (value is "") or (value is "true")
    value = yes

  else if (value is undefined) or (value is "false")
    value = no

  if isValid value, "boolean"
    query[key] = value
    return

  return Error "Expected '#{key}' to be a Boolean"

createRegex = (pattern) ->
  paramRE = /:[^\/]+/gi
  params = []
  source = "^#{pattern}$"
  while match = paramRE.exec pattern
    params.push match[0].slice 1
    source = source.replace match[0], "([^\/]+)"
  regex = new RegExp source, "g"
  regex.params = params
  return regex

matchRegex = (req, regex) ->
  regex.lastIndex = 0
  return no unless match = regex.exec req.path
  return yes if match.length is 1
  match.slice(1).forEach (value, index) ->
    req.query[regex.params[index] or index] = value
    return
  return yes

validateTypes = (obj, types) ->
  for key, type of types
    type = valido.get type
    if error = type.assert obj[key]
      return error key
  return
