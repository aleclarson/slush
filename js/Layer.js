// Generated by CoffeeScript 2.2.4
var Layer, assertValid, base, hookOnce, isValid;

assertValid = require("assertValid");

isValid = require("isValid");

Layer = class Layer {
  constructor() {
    this._pipes = [];
    this._drains = [];
    this;
  }

  use(fn) {
    assertValid(fn, "function");
    this._pipes.push(function(req, res) {
      return new Promise((resolve) => {
        hookOnce(req, "next", resolve);
        return fn.call(this, req, res, req.next);
      });
    });
    return this;
  }

  pipe(fn) {
    assertValid(fn, "function");
    this._pipes.push(fn);
    return this;
  }

  drain(fn) {
    assertValid(fn, "function");
    this._drains.push(fn);
    return this;
  }

  try(req, res) {
    var ctx, done, drains, index, pipes, resolve;
    done = req.next;
    pipes = this._pipes;
    drains = this._drains;
    ctx = {};
    index = -1;
    req.next = function() {
      var val;
      if (++index === pipes.length) {
        return done();
      }
      val = pipes[index].call(ctx, req, res);
      if (isValid(val, "promise")) {
        return val.then(resolve);
      } else {
        return resolve(val);
      }
    };
    resolve = function(val) {
      if (res.headersSent) {
        return;
      }
      if (!val) {
        return req.next();
      }
      if (val === true) {
        // `true` means "no response body"
        val = 204;
      }
      switch (val.constructor) {
        case Object:
        case String:
          return res.send(val);
        case Number:
          res.set("Content-Length", 0);
          res.status(val);
          return res.end();
      }
      // For security, arrays must be wrapped with an object: https://goo.gl/Y1LRf6
      if (Array.isArray(val)) {
        throw Error("Array responses are insecure");
      }
      throw Error("Invalid return type: " + val.constructor);
    };
    if (!drains.length) {
      return Promise.try(req.next);
    }
    return Promise.try(req.next).finally(function() {
      var fn, i, len;
      for (i = 0, len = drains.length; i < len; i++) {
        fn = drains[i];
        fn(req, res);
      }
    });
  }

};

module.exports = Layer;


// Helpers

// `finally` polyfill
if ((base = Promise.prototype).finally == null) {
  base.finally = function(fn) {
    var wrap;
    wrap = function(val) {
      fn();
      return val;
    };
    return this.then(wrap, wrap);
  };
}

if (Promise.try == null) {
  Promise.try = function(fn) {
    return Promise.resolve().then(fn);
  };
}

hookOnce = function(obj, key, hook) {
  var orig;
  orig = obj[key];
  obj[key] = function() {
    obj[key] = orig;
    return hook();
  };
};
