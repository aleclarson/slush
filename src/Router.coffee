
assertType = require "assertType"
Type = require "Type"

patternType = String.or RegExp
emptyArray = []
methods = ["get", "post", "put", "patch", "delete"]

type = Type "Router"

type.defineValues ->

  _matchers: []

methods.forEach (method) ->
  METHOD = method.toUpperCase()
  type.defineMethod method, (pattern, route) ->
    assertType pattern, patternType
    assertType route, Function

    if pattern.constructor is RegExp
      regex = pattern
      regex.params = emptyArray
    else
      regex = createRegex pattern

    @_matchers.push (req) ->
      return if req.method isnt METHOD
      return route if matchRegex req, regex
    return

type.defineMethods

  push: (matcher) ->
    assertType matcher, Function
    @_matchers.push matcher
    return

  match: (req) ->
    index = -1
    matchers = @_matchers
    while ++index < matchers.length
      match = matchers[index] req
      continue unless match
      return match if typeof match is "function"
      return -> match
    return null

module.exports = type.build()

createRegex = (input) ->
  paramRegex = /\{[^\}]+\}/g
  params = []
  pattern = "^#{input}$"
  while match = paramRegex.exec input
    params.push match[0].slice 1, -1
    pattern = pattern.replace match[0], "([^\/]+)"
  regex = new RegExp pattern, "g"
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
