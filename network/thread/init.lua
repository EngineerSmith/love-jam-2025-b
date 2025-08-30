local address = ...



require("love.data")
require("love.event")

local client = require("network.thread.client")
local enum = require("util.enum")
local serialize = require("util.serialize")

-- Global in thread
channelIn = love.thread.getChannel("networkIn")
POST = function(packetType, ...)
  love.event.push("networkOut", packetType, serialize.encode(...))
end

-- Connect to server
local success = client.connect(address)
if not success then
  local reason = enum.convert(enum.disconnect.badconnect, "disconnect")
  POST(enum.packetType.disconnect, reason, enum.disconnect.badconnect)
  return
else
  POST(enum.packetType.connected)
end

while true do
  -- COMMANDS IN
  local command, limit = channelIn:demand(0.005), 0
  while command and limit < 50 do
    if command == "quit" then
      -- stop network
      client.close()
      return
    end
    --
    if not client.isConnected() then
      break
    end
    --
    local target = command[1]
    local data = command[2]

    local channel = enum.channel.default
    local flags = "reliable"
    if target == "channel" then
      channel = command[2]
      if channel == enum.channel.unreliable then
        flags = "unreliable"
      elseif channel == enum.channel.unsequenced then
        flags = "unsequenced"
      end
      data = command[3]
    end

    if target == "send" then
      client.send(data, channel, flags)
    elseif target == "login" then
      client.login(data) -- data is username
    elseif target == "disconnect" then
      client.disconnect(data)
    end

    --
    command = channelIn:pop()
    limit = limit + 1
  end
  
  -- COMMANDS OUT
  if client.isConnected() then
    client.process(0.005)
  end
end