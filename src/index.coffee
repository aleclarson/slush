
# TODO: Support custom "404 Not Found" page.
# TODO: Support custom "500 Internal Error" page.

compression = require "compression"
assertTypes = require "assertTypes"
assertType = require "assertType"
setProto = require "setProto"
Promise = require "Promise"
express = require "express"
path = require "path"
now = require "performance-now"
log = require "log"
ip = require "ip"

optionTypes =
  port: Number.Maybe
  compress: Boolean.Maybe

__DEV__ = process.env.NODE_ENV isnt "production"

module.exports = (options = {}) ->
  assertTypes options, optionTypes

  app = express()

  server =
    if options.secure
    then require("https").createServer ssl(), app
    else require("http").createServer app

  server.maxHeadersCount = 50

  app.port = port =
    options.port or
    process.env.PORT or
    if options.secure then 4443 else 8000

  app.ready = do ->

    {promise, resolve} = Promise.defer()
    server.listen port, resolve

    protocol = if options.secure then "https" else "http"
    url = protocol + "://" + ip.address() + ":" + port

    return (callback) ->
      promise.then ->
        callback url

  if options.compress
    app.use compression()

  # The array of request handlers.
  app.pipes = []

  app.addPipe = (pipe) ->
    assertType pipe, Function
    app.pipes.push pipe
    return

  app.addPipes = (pipes) ->
    for pipe in pipes
      assertType pipe, Function
      app.pipes.push pipe
    return

  # Context shared by all requests.
  app.context = {}

  # Override this method to construct
  # a custom context for each request.
  app.createContext = -> {}

  # The entry point.
  app.use (req, res) ->

    # Create the context for this request.
    context = app.createContext req, res
    setProto context, app.context

    {length} = pipes = app.pipes
    index = -1

    measure = Function.prototype
    if __DEV__
      startTime = now()
      measure = ->
        log.moat 0
        status = res.statusCode
        if status is 200
        then log.green status + " "
        else log.red status + " "
        log.white req.method + " " + req.path + " "
        log.gray (now() - startTime).toFixed(3) + "ms"
        log.moat 0
        return

    next = ->

      if ++index is length
        res.status 404
        res.setHeader "Content-Type", "application/json"
        res.send {error: "Nothing exists here. Sorry!"}
        return

      result = pipes[index].call context, req, res
      if result and typeof result.then is "function"
      then result.then resolve
      else resolve result

    resolve = (result) ->
      return if res.headersSent
      return next() unless result

      if typeof result is "number"
        res.status result
        return res.end()

      res.setHeader "Content-Type", "application/json"

      # For security reasons, only send objects: http://stackoverflow.com/a/21510402/2228559
      if result.constructor is Object
        return res.send result

      if result instanceof Error
        res.status 400 if res.statusCode is 200
        return res.send {error: result.message}

      throw Error "Invalid return type: #{result.constructor}"

    # Start with the first pipe.
    Promise.try next

    # Wait for the response to finish.
    .then ->
      unless res.finished
        return onFinish res

    .then ->
      # Prevent DoS attacks using large POST bodies.
      req.destroy() if req.reading
      measure()

    # Uncaught errors end up here.
    .fail (error) ->
      log.moat 1
      log.white error.stack
      log.moat 1
      res.status 500
      res.send {error: "Something went wrong on our end. Sorry!"}
      measure()

  return app

#
# Helpers
#

ssl = ->
  fs = require "fs"
  key = fs.readFileSync path.resolve("ssl.key"), "utf8"
  cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"
  return {key, cert}

onFinish = (res) ->
  deferred = Promise.defer()
  res.on "finish", deferred.resolve
  res.on "error", deferred.reject
  return deferred.promise
