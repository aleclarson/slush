
# TODO: Destroy streams that are uploading too slow.

assertType = require "assertType"
Promise = require "Promise"

module.exports = (req, options = {}) ->
  return Promise.resolve() if req.body

  {promise, resolve, reject} = Promise.defer()

  chunks = []
  length = 0

  options.maxLength ?= 1e6 # 1mb
  req.on "data", consume = (chunk) ->

    length += chunk.length
    if length > options.maxLength
      req.removeListener "data", consume
      resolve Error "Cannot exceed #{options.maxLength / 1e6} mb"
      req.resume() # Drain the stream without reading.
      return

    chunks.push chunk
    return

  req.on "end", ->
    if length and promise.isPending
      req.body = Buffer.concat chunks
      if options.json
        parseJSON.call req, resolve
      else
        req.json = parseJSON
        resolve req.body

  req.on "error", reject

  return promise

#
# Helpers
#

parseJSON = (callback) ->
  assertType callback, Function
  body = @body.toString()
  return Promise.try ->
    try json = JSON.parse body
    catch error
      return Error "Failed to parse request body\n" + error.message
    unless json and json.constructor is Object
      return Error "Request body must be an object"
    return callback json
