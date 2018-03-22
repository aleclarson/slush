
wrapDefaults = require "wrap-defaults"
assertValid = require "assertValid"
setProto = require "setProto"
valido = require "valido"
now = require "performance-now"
qs = require "querystring"

createServer = require "./utils/createServer"
Response = require "../response"
Request = require "../request"
Layer = require "./Layer"

createTrustProxy = require "./utils/createTrustProxy"
etag = require "./utils/etag"

optionTypes = valido
  path: "string?"
  port: "number?"
  secure: "boolean?"
  getContext: "function?"
  maxHeaders: "number?"
  timeout: "number?"
  onError: "function?"
  onUnhandled: "function?"

setDefaults = wrapDefaults
  secure: false
  maxHeaders: 50
  timeout: 0

  onError: (error, res) ->
    res.status 500
    res.end()

  onUnhandled: (res) ->
    res.status 404
    res.end()

class App
  constructor: (opts) ->
    assertValid opts, optionTypes
    setDefaults opts

    @port = getPort opts
    @settings = Object.create null

    # Default settings
    @set "trust proxy", false
    @set "subdomain offset", 2

    @_layer = new Layer
    @_server = createServer opts, onRequest.bind this
    @_timeout = opts.timeout
    @_onError = opts.onError
    @_onUnhandled = opts.onUnhandled
    @

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

    return this

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
    return this

  emit: (eventId) ->
    switch arguments.length
      when 1 then @_server.emit eventId
      when 2 then @_server.emit eventId, arguments[1]
      else @_server.emit eventId, arguments[1], arguments[2]
    return this

  ready: (callback) ->
    if @_server.listening
    then callback()
    else @_server.once "listening", callback
    return this

  close: (callback) ->
    @_server.once "close", callback if callback
    @_server.close()
    return this

  # Used for testing.
  _send: (req, res) ->
    onRequest.call this, req, res

App.Layer = Layer
module.exports = App

#
# Helpers
#

getPort = (options) ->
  unless port = options.port
    unless port = parseInt process.env.PORT
      port = if options.secure then 443 else 8000
    options.port = port
  return port

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

  # The unhandled request handler.
  req.next = app._onUnhandled.bind req, res

  # Prevent long-running requests.
  if app._timeout > 0
    req.setTimeout onTimeout, app._timeout

  try
    # Attempt to handle the request.
    await app._layer.try req, res

    # Wait for the response to finish.
    unless res.finished
      await onFinish res

    # Prevent DoS attacks using large POST bodies.
    req.destroy() if req.reading

    if res.statusCode isnt 408
      app.emit "response", req, res

  catch error
    app.emit "requestError", error
    app._onError error, res
    app.emit "response", req, res

onFinish = (res) ->
  new Promise (resolve, reject) ->
    res.on "finish", resolve
    res.on "error", reject

onTimeout = (req, res) ->
  res.status 408
  res.send {error: "Request timed out"}
  @emit "response", req, res
  return
