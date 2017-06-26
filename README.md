
# slush v2.0.0 ![stable](https://img.shields.io/badge/stability-stable-4EBA0F.svg?style=flat)

Lightweight replacement to `express`.

```coffee
slush = require "slush"

app = slush()

app.ready (url) ->
  console.log "The server is listening at: #{url}"
```

### Options

- **port: Number?** If undefined, default to `process.env.PORT`, or `4443` (if HTTPS), or `8000` (if HTTP)
- **secure: Boolean?** If true, an HTTPS server is created with `ssl.key` and `ssl.crt` from the project root
- **maxHeaders: Number?** Limit the number of headers (defaults to 50)

### Request handling

The `slush` server uses a pipeline of request handlers (called "pipes").

```coffee
app.pipe (req, res) ->
  # Handle the request in here.
  # Calls to `pipe` can be chained.
```

The return value of each pipe is used to determine the server's next action.

Return `undefined` or `null` to skip the rest of the current pipe.

Return a `Number` literal to set the status code for an empty response.

Return an `Error` instance for invalid requests.

Return a `Promise` instance for asynchronous requests.
The resolved value is treated the same as synchronous return values.

The server will visit each pipe in the pipeline until `res.send` is called.
If that never happens, the server responds with "404 Not Found".

If an `Error` instance is thrown while inside a pipe, the server responds with "500 Internal Error".

-

Support for `express` middleware is included.

```coffee
app.use middleware
```

-

Use the `drain()` method for running code after the response is sent.

```coffee
app.drain (req, res) ->
  # The response has been sent.
```
