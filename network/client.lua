local client = {
  thread = love.thread.newThread("network/thread/init.lua"),
  state = "disconnected",
  _handlers = { },
  lastDisconnectReason = "",
}

local enum = require("util.enum")
local serialize = require("util.serialize")

for type_, _ in pairs(enum.packetType) do
  client._handlers[type_] = { }
end

client.connect = function(address)
  if client.thread:isRunning() then
    client.close()
  end
  client.thread:start(address)
  client.state = "pending"
end

client.threadErrorChecker = function()
  if client.thread then
    local err = client.thread:getError()
    if err then
      error(err)
    end
  end
end

client.addHandler = function(packetType, callback)
  if not client._handlers[packetType] then
    client._handlers[packetType] = { callback }
  else
    table.insert(client._handlers[packetType], callback)
  end
end

client.removeHandler = function(packetType, callback)
  if not client._handlers[packetType] then
    return
  end

  for i, cb in ipairs(client._handlers[packetType]) do
    if cb == callback then
      table.remove(client._handlers[packetType], i)
      return
    end
  end
end

client.isConnected = function()
  return client.state ~= "pending" and client.state ~= "disconnected"
end

local channelIn = love.thread.getChannel("networkIn")

client.login = function(username)
  channelIn:push({ enum.packetType.login, username })
end

client.send = function(type_, ...)
  channelIn:push({ "send", serialize.encode(type_, ...) })
end

client.handleNetworkOut = function(packetType, encoded)
  local decoded
  if encoded then
    local success
    success, decoded = pcall(serialize.decodeIndexed, encoded:getString())
    if not success then
      print("WARN< Could not decode incoming data. Error:", decoded )
      return
    end
  end

  if packetType == enum.packetType.receive then
    local type_ = decoded[1]
    if not type_ or type(client._handlers[type_]) ~= "table" then
      print("WARN< There were no handlers for received type: "..tostring(type_))
      return
    end
    for _, callback in ipairs(client._handlers[type_]) do
      callback(unpack(decoded, 2))
    end
  elseif packetType == enum.packetType.connected then
    if client.state ~= "pending" then
      -- act confused
      print("wa.wa. ssen..senpaiii\n\tI honestly don't know how you got here.")
      -- client.close() -- should we force close????
      return
    end
    client.state = "connected"
    for _, callback in ipairs(client._handlers[enum.packetType.connected]) do
      callback()
    end
  elseif packetType == enum.packetType.login then
    client.state = "loggedIn"
    for _, callback in ipairs(client._handlers[enum.packetType.login]) do
      callback()
    end
  elseif packetType == enum.packetType.disconnect then
    client.state = "disconnected"
    local reason, disconnectCode = decoded[1], decoded[2]
    client.lastDisconnectReason = "["..tostring(disconnectCode).."]: "..tostring(reason).." - "
    if disconnectCode == enum.disconnect.normal then
      client.lastDisconnectReason = client.lastDisconnectReason .. "Usually means it was mutual disconnect, or connection was lost."
    elseif disconnectCode == enum.disconnect.badconnect then
      client.lastDisconnectReason = client.lastDisconnectReason .. "Couldn't make a connection to the server."
    elseif disconnectCode == enum.disconnect.badserver then
      client.lastDisconnectReason = client.lastDisconnectReason .. "Server sent something faulty, or the server crashed."
    elseif disconnectCode == enum.disconnect.badusername or disconnectCode == enum.disconnect.badlogin then
      client.lastDisconnectReason = client.lastDisconnectReason .. "Server doesn't like your username or the server is borked."
    elseif disconnectCode == enum.disconnect.shutdown then
      client.lastDisconnectReason = client.lastDisconnectReason .. "Server has shutdown!"
    else
      client.lastDisconnectReason = client.lastDisconnectReason .. "I forgot to write more disconnect messages if you see this.\nTell someone what disconnect code you got!"
    end
    for _, callback in ipairs(client._handlers[enum.packetType.disconnect]) do
      callback(reason, disconnectCode)
    end
  else
    print("TODO handleNetworkOut:", tostring(packetType))
  end
end

client.close = function()
  if client.thread:isRunning() then
    channelIn:push("quit")
    client.thread:wait()
  end
  client.state = "disconnected"
end

return client