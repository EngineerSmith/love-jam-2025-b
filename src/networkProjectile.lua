local networkProjectile = { }
networkProjectile.__index = networkProjectile

local lg = love.graphics

local networkClient = require("network.client")

networkProjectile.new = function(type_, speed, sprite)
  local self = setmetatable({
    x = 0,
    y = 0,
    moveX = 0, -- move vector is direction of movement
    moveY = 0,
    type_ = type_,
    movementSpeed = speed or 500,
    sprite = sprite or nil,
    UUID = nil,
    localUUID = nil,
    isPredicted = false,
    ownerUUID = nil,
  }, networkProjectile)
  self.__index = self
  return self
end

-- Create new instance of the projectile
networkProjectile.create = function(self, x, y, moveX, moveY, doNotSend)
  local child = setmetatable({
    x = x,
    y = y,
    moveX = moveX,
    moveY = moveY,
    isPredicted = true,
    localUUID = require("network").getUUID(), -- generate a new UUID if one isn't supplied
    ownerUUID = networkClient.uuid,
  }, self)
  if doNotSend then
    return child
  end
  networkClient.sendWithTimestamp(
    "projectileCreate",
    child.type_,
    child.localUUID,
    child.x,
    child.y,
    child.moveX,
    child.moveY
  )
  return child
end

networkProjectile.reconcile = function(self, serverUUID)
  self.UUID = serverUUID
  self.isPredicted = false
end

networkProjectile.update = function(self, dt)
  self.x = self.x + self.moveX * self.movementSpeed * dt
  self.y = self.y + self.moveY * self.movementSpeed * dt
end

networkProjectile.getDrawY = function(self)
  return self.y
end

networkProjectile.draw = function(self)
  local sprite = self.sprite
  if not sprite then
    return
  end
  lg.push("all")
  if self.isPredicted then
    lg.setColor(1,1,1,.5)
  else
    lg.setColor(1,1,1,1)
  end
  lg.draw(sprite, self.x, self.y, 0, 1, 1, sprite:getWidth()/2, sprite:getHeight()/2)
  lg.pop()
end

return networkProjectile