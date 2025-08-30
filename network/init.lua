local client = require("network.client")

love.handlers["networkOut"] = function(...)
  client.handleNetworkOut(...)
end