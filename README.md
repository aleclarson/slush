
# slush v1.0.0 ![stable](https://img.shields.io/badge/stability-stable-4EBA0F.svg?style=flat)

```coffee
slush = require "slush"

# Create a `slush` server (basically an `express` wrapper).
app = slush()
```

The `slush` server must use HTTPS. Make sure `ssl.key` and `ssl.crt` exist in your project root.

### Request handling

The `slush` server uses a pipeline of request handlers (called "pipes").

Pipes are able to return a `Promise`. Once resolved, the server will determine its next action.

To continue to the next pipe, a pipe can return `undefined`.

If the request is invalid, a pipe can return an `Error` instance.

The request will continue to be handled by the next pipe until `res.send` is called.

If `res.send` is never called, the server responds with "404 Not Found".

If a pipe throws an `Error` instance, the server responds with "500 Internal Error".

```coffee
app.addPipe (req, res) ->
  # Handle request in here...
```

### Request contexts

Every pipe has a unique context. By default, an object literal is created.

You can set `app.createContext` to create the initial context for each request. The arguments are `(req, res)`.

Every context inherits from the global context, `app.context`.

```coffee
app.addPipe (req, res) ->
  @auth = authorize req
  return # The next pipe will have access to `this.auth`

# In some scenarios, it makes more sense to override `app.createContext`
app.createContext = (req, res) ->
  auth: authorize req
```
