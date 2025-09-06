local player = { }

local input = require("util.input")

local networkClient = require("network.client")
local networkManager = require("src.networkManager")

local playerProjectile = require("assets.sprites.projectile.player")

player.new = function(actor)
  player.actor = actor
end

player.update = function(dt)
  if not player.actor then
    return
  end

  local dx, dy = input.baton:get("move")
  player.actor:setMoveVector(-dx, dy)

  local dx, dy
  if input.isGamepadActive() then
    dx, dy = input.baton:get("face")
  else
    -- mouse
    local mx, my = love.mouse.getPosition()
    dx, dy = mx - player.actor.x, my - player.actor.y
  end
  player.actor:setFacingVector(dx, dy)

  if input.baton:pressed("attack") then
    local projectile = playerProjectile:create(0, 0, player.actor.faceX, player.actor.faceY)
    networkManager.addProjectile(projectile)
  end

  player.actor:update(dt)
end

player.updateNetwork = function()
  local a = player.actor
  networkClient.send("playerInfo", a.x, a.y, a.faceX, a.faceY)
end

player.draw = function()
  return player.actor
end

return player