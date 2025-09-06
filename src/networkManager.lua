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

local cb_projectileRejected = function(localUUID)
  networkManager.projectiles[localUUID] = nil
end

local cb_projectileDestroyed = function(uuid)
  networkManager.projectiles[uuid] = nil
end

local projectileMap = {
  ["player"] = require("assets.sprites.projectile.player"),
}

local cb_projectileReplicated = function(ownerUUID, uuid,localUUID, type_, x, y, moveX, moveY)
  local projectile = networkManager.projectiles[localUUID]
  if projectile then
    networkManager.projectiles[localUUID] = nil
    networkManager.projectiles[uuid] = projectile
    projectile:reconcile(uuid)
  else
    local p = projectileMap[type_]
    if not p then
      print("WARN> Couldn't find type: "..tostring(type_)..", to create projectile")
      return
    end
    local newProjectile = p:create(x, y, moveX, moveY)
    newProjectile:reconcile(uuid)
    networkManager.projectiles[uuid] = newProjectile
  end
end

networkManager.load = function(roomInfo)
  networkClient.addHandler("roomPlayers", cb_roomPlayers)
  networkClient.addHandler("projectileRejected", cb_projectileRejected)
  networkClient.addHandler("projectileReplicated", cb_projectileReplicated)

  networkManager.roomInfo = roomInfo
  networkManager.networkPlayers = { }
  networkManager.projectiles = { }

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
  networkClient.removeHandler("projectileRejected", cb_projectileRejected)
  networkClient.removeHandler("projectileReplicated", cb_projectileReplicated)

  networkManager.roomInfo = nil
  networkManager.networkPlayer = { }
  networkManager.projectiles = { }
end

networkManager.addProjectile = function(newProjectile)
  networkManager.projectiles[newProjectile.localUUID] = newProjectile
end

networkManager.update = function(dt)
  for _, networkPlayer in ipairs(networkManager.networkPlayers) do
    networkPlayer.player:update(dt)
  end
  for _, projectile in pairs(networkManager.projectiles) do
    projectile:update(dt)
  end
end

networkManager.draw = function(renderQueue)
  for _, networkPlayer in ipairs(networkManager.networkPlayers) do
    table.insert(renderQueue, networkPlayer.player:draw())
  end
  for _, projectile in pairs(networkManager.projectiles) do
    table.insert(renderQueue, projectile)
  end
end

return networkManager