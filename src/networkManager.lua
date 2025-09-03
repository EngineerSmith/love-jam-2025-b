local networkManager = { }
networkManager.__index = networkManager

local networkClient = require("network.client")
local networkPlayer = require("src.networkPlayer")

-- todo temp
local robotCharacter = require("assets.sprites.character.robot")

local cb_roomPlayers = function(roomPlayers)
  local serverPlayerSet = { }
  for _, playerData in ipairs(roomPlayers) do
    serverPlayerSet[playerData.uuid] = playerData
  end

  -- Remove any players no longer on the server
  for index = #networkManager.networkPlayers, 1, -1 do
    local networkPlayer = networkManager.networkPlayers[index]
    if not serverPlayerSet[networkPlayer.uuid] then
      table.remove(networkManager.networkPlayers, index)
    end
  end
  serverPlayerSet = nil

  -- Add, and update existing
  for _, playerData in ipairs(roomPlayers) do
    if playerData.uuid == networkClient.uuid then
      goto continue
    end
    local found = false
    for _, networkPlayer in ipairs(networkManager.networkPlayers) do
      if playerData.uuid == networkPlayer.uuid then
        networkPlayer.player:updatePosition(playerData)
        found = true
        break
      end
    end
    if not found then
      table.insert(networkManager.networkPlayers, {
        uuid = playerData.uuid,
        player = networkPlayer.new(robotCharacter:createActor(), playerData)
      })
    end
    ::continue::
  end
end

networkManager.load = function(roomInfo)
  networkClient.addHandler("roomPlayers", cb_roomPlayers)

  networkManager.roomInfo = roomInfo
  networkManager.networkPlayers = { }
  for _, player in ipairs(roomInfo) do
    if player.uuid ~= networkClient.uuid then
      print(player.uuid, networkClient.uuid)
      table.insert(networkManager.networkPlayers, {
        uuid = player.uuid,
        player = networkPlayer.new(robotCharacter:createActor(), player),
      })
    end
  end
end

networkManager.unload = function()
  networkClient.removeHandler("roomPlayers", cb_roomPlayers)

  networkManager.roomInfo = nil
  networkManager.networkPlayer = { }
end

networkManager.update = function(dt)
  for _, networkPlayer in ipairs(networkManager.networkPlayers) do
    networkPlayer.player:update(dt)
  end
end

networkManager.draw = function(renderQueue)
  for _, networkPlayer in ipairs(networkManager.networkPlayers) do
    table.insert(renderQueue, networkPlayer.player:draw())
  end
end

return networkManager