
# TODO: Support custom "404 Not Found" page.
# TODO: Support custom "500 Internal Error" page.

assertTypes = require "assertTypes"
assertType = require "assertType"
setProto = require "setProto"
Promise = require "Promise"
Type = require "Type"
path = require "path"
now = require "performance-now"
log = require "log"
ip = require "ip"
qs = require "querystring"

Response = require "../response"
Request = require "../request"
Layer = require "./Layer"

trustProxy = require "./utils/trustProxy"
etag = require "./utils/etag"

__DEV__ = process.env.NODE_ENV isnt "production"

type = Type "Application"

type.inherits Function

type.defineArgs
  port: Number
  secure: Boolean
  maxHeaders: Number

type.defineValues (options) ->

  port: getPort options

  settings: Object.create null

  _layer: Layer()

  _server: createServer this, options

  _listening: null

type.initInstance (options) ->
  @_server.maxHeadersCount = options.maxHeaders or 50
  @_listening = @_listen options
  return

type.defineFunction (req, res) ->
  req.timestamp = now()

  parts = req.url.split "?"
  req.path = parts[0]
  req.query = qs.parse parts[1]

  req.app = this
  req.res = res
  setProto req, Request

  res.app = this
  res.req = req
  setProto res, Response

  req.next = ->
    res.status 404
    res.send {error: "Nothing exists here. Sorry!"}
    return

  # Attempt to handle the request.
  @_layer.try req, res

  # Wait for the response to finish.
  .then ->
    unless res.finished
      return onFinish res

  .then ->
    # Prevent DoS attacks using large POST bodies.
    req.destroy() if req.reading
    measure req, res

  # Uncaught errors end up here.
  .fail (error) ->
    log.moat 1
    log.white error.stack
    log.moat 1
    res.status 500
    res.send {error: "Something went wrong on our end. Sorry!"}
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

  ready: (callback) ->
    @_listening.then callback

  _listen: (options) ->
    {port} = this
    {promise, resolve} = Promise.defer()
    @_server.listen port, ->
      protocol = if options.secure then "https" else "http"
      resolve protocol + "://" + ip.address() + ":" + port
    return promise

type.defineStatics

  Layer: Layer

  Router: require "./Router"

module.exports = type.build()

#
# Helpers
#

ssl = ->
  fs = require "fs"
  key = fs.readFileSync path.resolve("ssl.key"), "utf8"
  cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"
  return {key, cert}

createServer = (app, options) ->
  if options.secure
  then require("https").createServer ssl(), app
  else require("http").createServer app

getPort = (options) ->
  port = options.port or parseInt process.env.PORT
  return port if port
  return 4443 if options.secure
  return 8000

onFinish = (res) ->
  deferred = Promise.defer()
  res.on "finish", deferred.resolve
  res.on "error", deferred.reject
  return deferred.promise

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
