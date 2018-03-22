
createServer = (options, handler) ->
  server =
    if options.secure then do ->
      config = {}

      if getContext = options.getContext
        config.SNICallback = (hostname, done) ->
          done null, getContext hostname

      else
        fs = require "fs"
        path = require "path"
        config.key = fs.readFileSync path.resolve("ssl.key"), "utf8"
        config.cert = fs.readFileSync path.resolve("ssl.crt"), "utf8"

      require("https").createServer config, handler 
    else require("http").createServer handler

  server.maxHeadersCount = options.maxHeaders or 50
  server.listen options.path or options.port
  return server

module.exports = createServer
