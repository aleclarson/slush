
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
        queryTypes[key] = valido.get queryTypes[key]
      return (req, res) -> Promise.try ->
        return error if error = validateQuery req.query, queryTypes
        return responder.call req, req.query, res

    if @body is yes
      return (req, res) ->
        readBody(req).then ->
          return Error "Missing body" unless req.body
          return responder.call req, req.body, res

    if isValid @body, "object"
      bodyTypes = @body
      Object.keys(bodyTypes).forEach (key) ->
        bodyTypes[key] = valido.get bodyTypes[key]
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
    error = type.assert obj[key]
    return error key if error
  return

validateQuery = (obj, types) ->
  for key, type of types
    coalesce obj, key, type.name
    error = type.assert obj[key]
    return error key if error
  return

coalesce = (obj, key, type) ->
  value = obj[key]
  switch type

    when "number"
      value = parseInt value
      unless isNaN value
        obj[key] = value

    when "boolean"

      if (value is undefined) or (value is "false")
        obj[key] = false

      else if (value is "") or (value is "true")
        obj[key] = true

  return
