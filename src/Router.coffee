
assertType = require "assertType"
Type = require "Type"

Route = require "./Route"

methods = ["get", "post", "put", "patch", "delete"]

type = Type "Router"

type.defineValues ->

  _matchers: []

methods.forEach (method) ->
  type.defineMethod method, (pattern, responder) ->
    route = Route()

    if typeof pattern is 'function'
    then responder = pattern.call route
    else route.match pattern

    @_matchers.push route._build responder, method.toUpperCase()
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
