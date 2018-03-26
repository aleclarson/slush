assertValid = require "assertValid"
isValid = require "isValid"

class Layer
  constructor: ->
    @_pipes = []
    @_drains = []
    @

  use: (fn) ->
    assertValid fn, "function"

    @_pipes.push (req, res) ->
      new Promise (resolve) =>
        hookOnce req, "next", resolve
        fn.call this, req, res, req.next

    return this

  pipe: (fn) ->
    assertValid fn, "function"
    @_pipes.push fn
    return this

  drain: (fn) ->
    assertValid fn, "function"
    @_drains.push fn
    return this

  try: (req, res) ->
    done = req.next
    pipes = @_pipes
    drains = @_drains

    ctx = {}
    index = -1
    req.next = ->
      return done() if ++index is pipes.length
      val = pipes[index].call ctx, req, res
      if isValid val, "promise"
      then val.then resolve
      else resolve val

    resolve = (val) ->
      return if res.headersSent
      return req.next() unless val

      # `true` means "no response body"
      val = 204 if val is true

      switch val.constructor
        when Object, String
          return res.send val
        when Number
          res.set "Content-Length", 0
          res.status val
          return res.end()

      # For security, arrays must be wrapped with an object: https://goo.gl/Y1LRf6
      if Array.isArray val
        throw Error "Array responses are insecure"

      throw Error "Invalid return type: " + val.constructor

    unless drains.length
      return Promise.try req.next

    Promise.try req.next
    .finally ->
      fn req, res for fn in drains
      return

module.exports = Layer

#
# Helpers
#

# `finally` polyfill
Promise::finally ?= (fn) ->
  wrap = (val) ->
    fn()
    val
  @then wrap, wrap

Promise.try ?= (fn) ->
  Promise.resolve().then fn

hookOnce = (obj, key, hook) ->
  orig = obj[key]
  obj[key] = ->
    obj[key] = orig
    hook()
  return
