local client = require("network.client")

love.handlers["networkOut"] = function(...)
  client.handleNetworkOut(...)
end

local network = { }

local uuidRNG = love.math.newRandomGenerator(os.time())
local uuidTemplate = "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx"
network.getUUID = function()
  return uuidTemplate:gsub("[x]", function(_)
    return ("%x"):format(uuidRNG:random(0, 0xf))
  end)
end

return network