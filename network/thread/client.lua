local ld = love.data

local client = {
  defaultPort = "53135",
  timeOffset = 0,
}

local enet = require("enet")

local enum = require("util.enum")
local serialize = require("util.serialize")
local options = require("util.option")

client.connect = function(address)
  if not address:find(":") then
    address = address .. ":" .. client.defaultPort
  end
  if client.host then
    client.close()
  end

  print("> Creating host")
  client.host = enet.host_create(nil, 1, enum.channelCount, 0, 0)
  client.server = client.host:connect(address, enum.channelCount, 0)
  print("> Connecting...")
  local success = client.host:service(5000) -- 5sec timeout
  if not success or success.type ~= "connect" or success.peer ~= client.server then
    if success and success.peer ~= server then
      success.peer:disconnect_now(enum.disconnect.badconnect)
    end
    client.close()
    print("> Connection failed")
    return false
  end

  print("> Connection successful")
  return true
end

client.isConnected = function()
  return client.host and client.server
end

client.login = function(username)
  return client.send(serialize.encode(username), enum.channel.default, "reliable", true)
end

local localTime = os.time() -- Set at each event interval to get the closest time value to the received time
client.timeSync = function(serverTime)
  local RTT = client.server:last_round_trip_time() -- latest RTT
  local latency_seconds = (RTT / 2) / 1000

  local estimatedServerTimeAtReceive = serverTime + latency_seconds
  client.timeOffset = estimatedServerTimeAtReceive - localTime
  -- print("Offset:", client.timeOffset)
end

client.getNetworkTimestamp = function()
  return os.time() + client.timeOffset
end

client.send = function(data, channel, flags, _skipLogin)
  if not client.loggedIn and not _skipLogin then
    print("WARN< You can't send messages until you're logged in")
    return false
  end
  local compressData
  if data then
    local success
    success, compressData = pcall(ld.compress, "data", options.compressionFunction, data)
    if not success then
      print("WARN< Could not compress outgoing data")
      return false
    end
  end
  client.server:send(compressData:getPointer(), compressData:getSize(), channel, flags)
  return true
end

client.process = function(budgetS)
  local event, limit = client.host:service(budgetS*1000), 0
  while event do
    localTime = os.time()
    if event.type == "receive" then
      local success, data = pcall(ld.decompress, "data", options.compressionFunction, event.data)
      if not success then
        print("WARN< Incoming data ignored! Could not depression:", data)
        goto continue
      end
      if client.loggedIn then
        POST(enum.packetType.receive, data)
      else -- not client.loggedIn
        local success, decoded = pcall(serialize.decodeIndexed, data:getString())
        if not success then
          print("WARN> Could not decode incoming encoded data confirming login. Disconnecting. Issue:", tostring(decoded))
          return client.disconnect(enum.disconnect.badserver)
        end
        if decoded[1] == "timeSync" then
          client.timeSync(decoded[2])
          goto continue
        elseif decoded[1] ~= enum.packetType.login then
          print("WARN> Didn't receive confirming login packetType. Data ignored! Type: "..tostring(decoded[1]))
          goto continue
        end
        client.loggedIn = true
        client.uuid = decoded[2]
        POST(enum.packetType.login, serialize.encode(client.uuid))
      end
    elseif event.type == "connect" then
      if event.peer ~= server then
        event.peer:disconnect_now(enum.disconnect.badconnect)
        print("WARN> Unknown connection handshake from "..tostring(event.peer))
      end
    elseif event.type == "disconnect" then
      local reason = enum.convert(event.data, "disconnect")
      POST(enum.packetType.disconnect, serialize.encode(reason, event.data))
      return client.disconnect(enum.disconnect.normal)
    end
    ::continue::
    limit = limit + 1
    if limit >= 50 then
      break
    end
    event = client.host:check_events()
  end
end

client.disconnect = function(reason)
  client.server:disconnect(tonumber(reason) or enum.disconnect.normal)
  client.close()
end

client.close = function()
  client.loggedIn = false
  client.timeOffset = 0

  if client.server then
    local state = client.server:state()
    if state ~= "disconnected" and state ~= "disconnecting" then
      client.server:disconnect(enum.disconnect.normal)
      local reason = enum.convert(enum.disconnect.normal, "disconnect")
      POST(enum.packetType.disconnect, serialize.encode(reason, enum.disconnect.normal))
    end
  end

  if client.host then
    client.host:flush()
    client.host:destroy()
    client.host = nil
  end
  client.server = nil
end

return client