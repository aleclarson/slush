
assertTypes = require "assertTypes"
assertType = require "assertType"
setProto = require "setProto"
Promise = require "Promise"
Type = require "Type"
path = require "path"
now = require "performance-now"
log = require "log"
ip = require "ip"

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

  _onError: options.onError or handle500

# The root request handler.
onRequest = (req, res) ->
  app = this
  req.timestamp = now()

  parts = req.url.split "?"
  req.path = parts[0]
  req.query = parseQuery parts[1]

  req.app = app
  req.res = res
  setProto req, Request

  res.app = app
  res.req = req
  setProto res, Response

  # The default 404 response handler.
  req.next = handle404

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
      app.emit "response", res
      measure req, res

  .fail (error) ->
    onError error, res
    app.emit "response", res
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

type.defineStatics

  Layer: Layer

  Router: require "./Router"

module.exports = type.build()

#
# Helpers
#

getPort = (options) ->
  port = options.port or parseInt process.env.PORT
  return port if port
  return 4443 if options.secure
  return 8000

parseQuery = (query) ->
  parsed = {}
  return parsed unless query
  pairs = query.split "&"
  for pair in pairs
    pair = pair.split "="
    if pair.length is 1
    then parsed[pair[0]] = yes
    else parsed[pair[0]] = decodeURIComponent pair[1]
  return parsed

onFinish = (res) ->
  deferred = Promise.defer()
  res.on "finish", deferred.resolve
  res.on "error", deferred.reject
  return deferred.promise

onTimeout = (req, res) ->
  res.status 408
  res.send {error: "Request timed out"}
  @emit "response", req
  measure req, res

measure = (req, res) ->
  return unless __DEV__
  log.moat 0
  status = res.statusCode
  if status is 200
  then log.green status + " "
  else log.red status + " "
  log.white req.method + " " + req.path + " "
  log.gray (now() - req.timestamp).toFixed(3) + "ms"
  log.moat 0
  return

# Attached to the request object.
handle404 = ->
  @res.status 404
  @res.send {error: "Nothing exists here. Sorry!"}
  return

# The default handler when the server throws an error.
handle500 = (error, res) ->

  log.moat 1
  log.white error.stack
  log.moat 1

  res.status 500
  res.send {error: "Something went wrong on our end. Sorry!"}
  return
