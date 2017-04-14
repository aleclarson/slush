
compression = require "compression"
assertTypes = require "assertTypes"
assertType = require "assertType"
setProto = require "setProto"
Promise = require "Promise"
express = require "express"
isType = require "isType"
path = require "path"
now = require "performance-now"
log = require "log"
ip = require "ip"

optionTypes =
  port: Number.Maybe
  compress: Boolean.Maybe

module.exports = (options = {}) ->
  assertTypes options, optionTypes

  app = express()

  server =
    if options.secure
    then require("https").createServer ssl(), app
    else require("http").createServer app

  port =
    options.port or
    process.env.PORT or
    if options.secure then 4443 else 8000

  app.onceReady = do ->

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

    # Continue to the next pipe.
    startTime = null
    next = ->
      return if ++index is length
      startTime = now()
      result = pipes[index].call context, req, res
      if result and isType result.then, Function
      then result.then done
      else done result

    # Attempt to send the response.
    done = (result) ->
      log.it req.method + " " + req.path + " " + (now() - startTime).toFixed(3) + "ms"

      return if res._headerSent
      return next() if result is undefined

      if isType result, Object
        return res.send result

      if result instanceof Error
        res.status 400 if res.statusCode is 200
        return res.send {error: result.message}

    # Start with the first pipe.
    Promise.try next

    # Unhandled requests end up here.
    .then ->
      return if res._headerSent
      res.status 404
      res.send {error: "This page does not exist. Sorry!"}
      # TODO: Support custom "404 Not Found" page.

    # Uncaught errors end up here.
    .fail (error) ->
      console.log error.stack
      res.status 500
      res.send {error: "Something bad happened. And it's not your fault. Sorry!"}
      # TODO: Support custom "500 Internal Error" page.

  return app

#
# Helpers
#

ssl = ->
  fs = require "fs"
  key = fs.readFileSync path.resolve("ssl.key"), "utf8"
  cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"
  return {key, cert}
