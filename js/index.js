// Generated by CoffeeScript 1.12.4
var Layer, Promise, Request, Response, Type, __DEV__, createServer, default404, default500, etag, getPort, log, measure, now, onFinish, onRequest, onTimeout, qs, setProto, trustProxy, type;

setProto = require("setProto");

Promise = require("Promise");

Type = require("Type");

now = require("performance-now");

log = require("log");

qs = require("querystring");

createServer = require("./utils/createServer");

Response = require("../response");

Request = require("../request");

Layer = require("./Layer");

trustProxy = require("./utils/trustProxy");

etag = require("./utils/etag");

__DEV__ = process.env.NODE_ENV !== "production";

type = Type("Application");

type.defineArgs({
  port: Number,
  secure: Boolean,
  maxHeaders: Number,
  timeout: Number,
  onError: Function
});

type.defineValues(function(options) {
  return {
    port: getPort(options),
    settings: Object.create(null),
    _layer: Layer(),
    _server: createServer(options, onRequest.bind(this)),
    _timeout: options.timeout,
    _onError: options.onError || default500
  };
});

onRequest = function(req, res) {
  var app, parts;
  app = this;
  req.startTime = now();
  parts = req.url.split("?");
  req.path = parts[0];
  req.query = qs.parse(parts[1]);
  setProto(req.query, Object.prototype);
  req.app = app;
  req.res = res;
  setProto(req, Request);
  res.app = app;
  res.req = req;
  setProto(res, Response);
  req.next = default404.bind(req, res);
  if (app._timeout > 0) {
    req.setTimeout(onTimeout, app._timeout);
  }
  return app._layer["try"](req, res).then(function() {
    if (!res.finished) {
      return onFinish(res);
    }
  }).then(function() {
    if (req.reading) {
      req.destroy();
    }
    if (res.statusCode !== 408) {
      app.emit("response", res);
      return measure(req, res);
    }
  }).fail(function(error) {
    app._onError(error, res);
    app.emit("response", res);
    return measure(req, res);
  });
};

type.defineMethods({
  get: function(name) {
    return this.settings[name];
  },
  set: function(name, value) {
    if (arguments.length === 1) {
      return this.settings[name];
    }
    this.settings[name] = value;
    switch (name) {
      case "etag":
        this.set("etag fn", etag.compile(value));
        break;
      case "trust proxy":
        this.set("trust proxy fn", trustProxy(value));
    }
  },
  use: function(fn) {
    this._layer.use(fn);
    return this;
  },
  pipe: function(fn) {
    this._layer.pipe(fn);
    return this;
  },
  drain: function(fn) {
    this._layer.drain(fn);
    return this;
  },
  on: function(eventId, handler) {
    return this._server.on(eventId, handler);
  },
  emit: function(eventId, data) {
    return this._server.emit(eventId, data);
  },
  ready: function(callback) {
    if (this._server.listening) {
      return callback();
    } else {
      return this._server.once("listening", callback);
    }
  },
  _send: function(req, res) {
    return onRequest.call(this, req, res);
  }
});

type.defineStatics({
  Layer: Layer,
  Router: require("./Router")
});

module.exports = type.build();

getPort = function(options) {
  var port;
  if (!(port = options.port)) {
    if (!(port = parseInt(process.env.PORT))) {
      port = options.secure ? 443 : 8000;
    }
    options.port = port;
  }
  return port;
};

onFinish = function(res) {
  var deferred;
  deferred = Promise.defer();
  res.on("finish", deferred.resolve);
  res.on("error", deferred.reject);
  return deferred.promise;
};

onTimeout = function(req, res) {
  res.status(408);
  res.send({
    error: "Request timed out"
  });
  this.emit("response", req);
  return measure(req, res);
};

measure = Function.prototype;

if (__DEV__) {
  measure = function(req, res) {
    var elapsedTime, status;
    elapsedTime = req.elapsedTime;
    log.moat(0);
    status = res.statusCode;
    if (status === 200) {
      log.green(status + " ");
    } else {
      log.red(status + " ");
    }
    log.white(req.method + " " + req.path + " ");
    log.gray(elapsedTime + "ms");
    log.moat(0);
  };
}

default404 = function(res) {
  res.status(404);
  res.send({
    error: "Nothing exists here. Sorry!"
  });
};

default500 = function(error, res) {
  log.moat(1);
  log.white(error.stack);
  log.moat(1);
  res.status(500);
  res.send({
    error: "Something went wrong on our end. Sorry!"
  });
};