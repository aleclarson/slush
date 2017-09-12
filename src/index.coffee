
setProto = require "setProto"
Promise = require "Promise"
Type = require "Type"
now = require "performance-now"
log = require "log"
qs = require "querystring"

createServer = require "./utils/createServer"
Response = require "../response"
Request = require "../request"
Layer = require "./Layer"

trustProxy = require "./utils/trustProxy"
etag = require "./utils/etag"

__DEV__ = process.env.NODE_ENV isnt "production"

type = Type "Application"

type.defineArgs
  port: Number
  secure: Boolean
  maxHeaders: Number
  timeout: Number
  onError: Function

type.defineValues (options) ->

  port: getPort options

  settings: Object.create null

  _layer: Layer()

  _server: createServer options, onRequest.bind this

  _timeout: options.timeout

  _onError: options.onError or default500

# The root request handler.
onRequest = (req, res) ->
  app = this
  req.startTime = now()

  parts = req.url.split "?"
  req.path = parts[0]
  req.query = qs.parse parts[1]
  setProto req.query, Object.prototype

  req.app = app
  req.res = res
  setProto req, Request

  res.app = app
  res.req = req
  setProto res, Response

  # The default 404 response handler.
  req.next = default404.bind req, res

  # Prevent long-running requests.
  if app._timeout > 0
    req.setTimeout onTimeout, app._timeout

  # Attempt to handle the request.
  app._layer.try req, res

  # Wait for the response to finish.
  .then ->
    unless res.finished
      return onFinish res

  .then ->

    # Prevent DoS attacks using large POST bodies.
    req.destroy() if req.reading

    if res.statusCode isnt 408
      app.emit "response", req, res
      measure req, res

  .fail (error) ->
    app._onError error, res
    app.emit "response", req, res
    measure req, res

type.defineMethods

  get: (name) ->
    return @settings[name]

  set: (name, value) ->

    # Backwards compatibility with `express`
    return @settings[name] if arguments.length is 1

    @settings[name] = value

    switch name

      when "etag"
        @set "etag fn", etag.compile value

      when "trust proxy"
        @set "trust proxy fn", trustProxy value

    return

  use: (fn) ->
    @_layer.use fn
    return this

  pipe: (fn) ->
    @_layer.pipe fn
    return this

  drain: (fn) ->
    @_layer.drain fn
    return this

  on: (eventId, handler) ->
    @_server.on eventId, handler

  emit: (eventId, data) ->
    @_server.emit eventId, data

  ready: (callback) ->
    if @_server.listening
    then callback()
    else @_server.once "listening", callback

  # Used for testing.
  _send: (req, res) ->
    onRequest.call this, req, res

type.defineStatics

  Layer: Layer

  Router: require "./Router"

module.exports = type.build()

#
# Helpers
#

getPort = (options) ->
  unless port = options.port
    unless port = parseInt process.env.PORT
      port = if options.secure then 443 else 8000
    options.port = port
  return port

onFinish = (res) ->
  deferred = Promise.defer()
  res.on "finish", deferred.resolve
  res.on "error", deferred.reject
  return deferred.promise

onTimeout = (req, res) ->
  res.status 408
  res.send {error: "Request timed out"}
  @emit "response", req, res
  measure req, res

# Only measure response times during development.
measure = Function.prototype
if __DEV__
  measure = (req, res) ->
    {elapsedTime} = req
    log.moat 0
    status = res.statusCode
    if status is 200
    then log.green status + " "
    else log.red status + " "
    log.white req.method + " " + req.path + " "
    log.gray elapsedTime + "ms"
    log.moat 0
    return

# Attached to the request object.
default404 = (res) ->
  res.status 404
  res.send {error: "Nothing exists here. Sorry!"}
  return

# The default handler when the server throws an error.
default500 = (error, res) ->

  log.moat 1
  log.white error.stack
  log.moat 1

  res.status 500
  res.send {error: "Something went wrong on our end. Sorry!"}
  return
