
assertTypes = require "assertTypes"
compression = require "compression"
setProto = require "setProto"
Promise = require "Promise"
express = require "express"
https = require "https"
path = require "path"

optionTypes =
  port: Number.Maybe
  compress: Boolean.Maybe

module.exports = (options) ->
  assertTypes options, optionTypes

  deferred = Promise.defer()

  app = express()

  app.use (req) ->
    req.path = req.path.slice 1
    req.parts = req.path.split "/"
    req.next()

  port = options.port or process.env.PORT or 4443
  server = https.createServer ssl(), app
  server.listen port, resolve

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
    next = ->
      return if ++index is length
      result = pipes[index].call context, req, res
      if isType result, Promise
      then result.then done
      else done result

    # Attempt to send the response.
    done = (result) ->
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
      res.status 500
      res.send {error: "Something bad happened. And it's not your fault. Sorry!"}
      # TODO: Support custom "500 Internal Error" page.

  return app

#
# Helpers
#

ssl = ->
  fs = require "fs"
  key = fs.readFileSync path.resolve "ssl.key", "utf8"
  cert = fs.readFileSync path.resolve "ssl.crt", "utf8"
  return {key, cert}
