// Generated by CoffeeScript 1.12.4
var Layer, Promise, Request, Response, Type, __DEV__, assertType, assertTypes, createServer, etag, getPort, ip, log, measure, now, onFinish, path, qs, setProto, ssl, trustProxy, type;

assertTypes = require("assertTypes");

assertType = require("assertType");

setProto = require("setProto");

Promise = require("Promise");

Type = require("Type");

path = require("path");

now = require("performance-now");

log = require("log");

ip = require("ip");

qs = require("querystring");

Response = require("../response");

Request = require("../request");

Layer = require("./Layer");

trustProxy = require("./utils/trustProxy");

etag = require("./utils/etag");

__DEV__ = process.env.NODE_ENV !== "production";

type = Type("Application");

type.inherits(Function);

type.defineArgs({
  port: Number,
  secure: Boolean,
  maxHeaders: Number
});

type.defineValues(function(options) {
  return {
    port: getPort(options),
    settings: Object.create(null),
    _layer: Layer(),
    _server: createServer(this, options),
    _listening: null
  };
});

type.initInstance(function(options) {
  this._server.maxHeadersCount = options.maxHeaders || 50;
  this._listening = this._listen(options);
});

type.defineFunction(function(req, res) {
  var parts;
  req.timestamp = now();
  parts = req.url.split("?");
  req.path = parts[0];
  req.query = qs.parse(parts[1]);
  req.app = this;
  req.res = res;
  setProto(req, Request);
  res.app = this;
  res.req = req;
  setProto(res, Response);
  req.next = function() {
    res.status(404);
    res.send({
      error: "Nothing exists here. Sorry!"
    });
  };
  return this._layer["try"](req, res).then(function() {
    if (!res.finished) {
      return onFinish(res);
    }
  }).then(function() {
    if (req.reading) {
      req.destroy();
    }
    return measure(req, res);
  }).fail(function(error) {
    log.moat(1);
    log.white(error.stack);
    log.moat(1);
    res.status(500);
    res.send({
      error: "Something went wrong on our end. Sorry!"
    });
    return measure(req, res);
  });
});

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
  ready: function(callback) {
    return this._listening.then(callback);
  },
  _listen: function(options) {
    var port, promise, ref, resolve;
    port = this.port;
    ref = Promise.defer(), promise = ref.promise, resolve = ref.resolve;
    this._server.listen(port, function() {
      var protocol;
      protocol = options.secure ? "https" : "http";
      return resolve(protocol + "://" + ip.address() + ":" + port);
    });
    return promise;
  }
});

type.defineStatics({
  Layer: Layer,
  Router: require("./Router")
});

module.exports = type.build();

ssl = function() {
  var cert, fs, key;
  fs = require("fs");
  key = fs.readFileSync(path.resolve("ssl.key"), "utf8");
  cert = fs.readFileSync(path.resolve("ssl.crt"), "utf8");
  return {
    key: key,
    cert: cert
  };
};

createServer = function(app, options) {
  if (options.secure) {
    return require("https").createServer(ssl(), app);
  } else {
    return require("http").createServer(app);
  }
};

getPort = function(options) {
  var port;
  port = options.port || parseInt(process.env.PORT);
  if (port) {
    return port;
  }
  if (options.secure) {
    return 4443;
  }
  return 8000;
};

onFinish = function(res) {
  var deferred;
  deferred = Promise.defer();
  res.on("finish", deferred.resolve);
  res.on("error", deferred.reject);
  return deferred.promise;
};

measure = function(req, res) {
  var status;
  if (!__DEV__) {
    return;
  }
  log.moat(0);
  status = res.statusCode;
  if (status === 200) {
    log.green(status + " ");
  } else {
    log.red(status + " ");
  }
  log.white(req.method + " " + req.path + " ");
  log.gray((now() - req.timestamp).toFixed(3) + "ms");
  log.moat(0);
};
