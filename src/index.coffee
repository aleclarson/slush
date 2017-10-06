
setProto = require "setProto"
Promise = require "Promise"
Type = require "Type"
now = require "performance-now"
qs = require "querystring"

createServer = require "./utils/createServer"
Response = require "../response"
Request = require "../request"
Layer = require "./Layer"

createTrustProxy = require "./utils/createTrustProxy"
etag = require "./utils/etag"

__DEV__ = process.env.NODE_ENV isnt "production"

type = Type "Application"

type.defineArgs
  port: Number
  secure: Boolean
  getContext: Function
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

# Default settings
type.initInstance ->
  @set "trust proxy", false
  @set "subdomain offset", 2
  return

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

  .fail (error) ->
    app._onError error, res
    app.emit "response", req, res

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
        @set "trust proxy fn", createTrustProxy value

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

  emit: (eventId) ->
    switch arguments.length
      when 1 then @_server.emit eventId
      when 2 then @_server.emit eventId, arguments[1]
      else @_server.emit eventId, arguments[1], arguments[2]

  ready: (callback) ->
    if @_server.listening
    then callback()
    else @_server.once "listening", callback

  close: (callback) ->
    @_server.once "close", callback if callback
    @_server.close()
    return this

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
  return

# Attached to the request object.
default404 = (res) ->
  res.status 404
  res.send {error: "Nothing exists here. Sorry!"}
  return

# The default handler when the server throws an error.
default500 = (error, res) ->
  @emit "requestError", error
  res.status 500
  res.send {error: "Something went wrong on our end. Sorry!"}
  return
