local lg = love.graphics

local audioManager = require("util.audioManager")
local ui = require("util.ui")
audioManager.setVolumeAll()

local networkClient = require("network.client")

local scene = { }

local currentPingValue = -1
local cb_ping = function(pingTime)
  currentPingValue = pingTime
end

scene.load = function(roomInfo)
  networkClient.addHandler("ping", cb_ping)
end

scene.unload = function()
  networkClient.removeHandler("ping", cb_ping)
end

scene.draw = function()
  love.graphics.clear()
  lg.push("all")
    local font = ui.getFont(14, "fonts.regular.bold", scene.scale)
    lg.setColor(.5,.5,.5,1)
    lg.print("Ping: "..(currentPingValue).."ms", font, 0, 0)
  lg.pop()
end

return scene