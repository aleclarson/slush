
createServer = (opts, handler) ->
  server =
    if opts.secure then do ->
      config = {}

      if getContext = opts.getContext
        config.SNICallback = (hostname, done) ->
          done null, getContext hostname

      else
        fs = require "fs"
        path = require "path"
        config.key = fs.readFileSync path.resolve("ssl.key"), "utf8"
        config.cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"

      require("https").createServer config, handler
    else require("http").createServer handler

  server.maxHeadersCount = opts.maxHeaders
  server.listen opts.sock or opts.port
  return server

module.exports = createServer
