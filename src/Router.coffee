
assertValid = require "assertValid"
isValid = require "isValid"
Type = require "Type"

Route = require "./Route"

methods = ["get", "post", "put", "patch", "delete"]

type = Type "Router"

type.defineValues ->

  _matchers: []

methods.forEach (method) ->
  type.defineMethod method, (pattern, responder) ->
    route = Route()

    if isValid pattern, "function"
    then responder = pattern.call route
    else route.match pattern

    @_matchers.push route._build responder, method.toUpperCase()
    return

type.defineMethods

  push: (matcher) ->
    assertValid matcher, "function"
    @_matchers.push matcher
    return

  match: (req, pathname = req.path) ->
    index = -1
    matchers = @_matchers
    while ++index < matchers.length
      continue unless match = matchers[index] req, pathname
      return match if typeof match is "function"
      return -> match
    return null

  matcher: (pathname) -> (req, res) ->
    if route = router.match req, pathname
      return route req, res

  extend: (fns) ->
    fn this for fn in fns
    return

module.exports = type.build()
