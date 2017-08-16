
createServer = (options, handler) ->
  server = if options.secure then https handler else http handler
  server.maxHeadersCount = options.maxHeaders or 50
  server.listen options.port
  return server

http = (handler) ->
  require("http").createServer handler

https = (handler) ->
  fs = require "fs"
  path = require "path"
  key = fs.readFileSync path.resolve("ssl.key"), "utf8"
  cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"
  require("https").createServer {key, cert}, handler

module.exports = createServer
