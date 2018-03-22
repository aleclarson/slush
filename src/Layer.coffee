
assertValid = require "assertValid"
Promise = require "Promise"
isValid = require "isValid"

class Layer
  constructor: ->
    @_pipes = []
    @_drains = []
    @

  use: (fn) ->
    assertValid fn, "function"
    @_pipes.push (req, res) ->
      context = this
      new Promise (resolve) ->
        hookOnce req, "next", resolve
        fn.call context, req, res, req.next
    return

  pipe: (fn) ->
    assertValid fn, "function"
    @_pipes.push fn
    return

  drain: (fn) ->
    assertValid fn, "function"
    @_drains.push fn
    return

  try: (req, res) ->
    done = req.next
    pipes = @_pipes
    drains = @_drains

    context = {}
    index = -1
    req.next = ->
      return done() if ++index is pipes.length
      result = pipes[index].call context, req, res
      if result and isValid result.then, "function"
      then result.then resolve
      else resolve result

    resolve = (result) ->
      return if res.headersSent
      return req.next() unless result

      if result.constructor is Object
        return res.send result

      if isValid result, "string"
        return res.send result

      if isValid result, "number"
        res.set "Content-Length", 0
        res.status result
        return res.end()

      if isValid result, "error"
        res.status 400 if res.statusCode < 300
        return res.send {error: result.message}

      # For security, arrays must be wrapped with an object: https://goo.gl/Y1LRf6
      if Array.isArray result
        throw Error "Array responses are insecure"

      throw Error "Invalid return type: " + result.constructor

    unless drains.length
      return Promise.try req.next

    drain = ->
      fn req, res for fn in drains
      return

    Promise.try req.next
    .then drain, drain

module.exports = Layer

#
# Helpers
#

hookOnce = (obj, key, hook) ->
  orig = obj[key]
  obj[key] = ->
    obj[key] = orig
    hook()
  return
