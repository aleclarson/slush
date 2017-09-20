// Generated by CoffeeScript 1.12.4
var Route, Type, assertType, methods, type;

assertType = require("assertType");

Type = require("Type");

Route = require("./Route");

methods = ["get", "post", "put", "patch", "delete"];

type = Type("Router");

type.defineValues(function() {
  return {
    _matchers: []
  };
});

methods.forEach(function(method) {
  return type.defineMethod(method, function(pattern, responder) {
    var route;
    route = Route();
    if (typeof pattern === 'function') {
      responder = pattern.call(route);
    } else {
      route.match(pattern);
    }
    this._matchers.push(route._build(responder, method.toUpperCase()));
  });
});

type.defineMethods({
  push: function(matcher) {
    assertType(matcher, Function);
    this._matchers.push(matcher);
  },
  match: function(req) {
    var index, match, matchers;
    index = -1;
    matchers = this._matchers;
    while (++index < matchers.length) {
      match = matchers[index](req);
      if (!match) {
        continue;
      }
      if (typeof match === "function") {
        return match;
      }
      return function() {
        return match;
      };
    }
    return null;
  }
});

module.exports = type.build();
