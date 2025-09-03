local networkPlayer = { }
networkPlayer.__index = networkPlayer

networkPlayer.new = function(actor, playerData)
  actor.x = playerData.x
  actor.y = playerData.y
  actor.faceX = playerData.faceX
  actor.faceY = playerData.faceY
  local self = setmetatable({
    actor = actor,
  }, networkPlayer)
  -- Setup networkPlayer values
  self:updatePosition(playerData)
  return self
end

networkPlayer.updatePosition = function(self, playerData)
  local dx = playerData.x - self.actor.x
  local dy = playerData.y - self.actor.y
  local mag = math.sqrt(dx^2 + dy^2)

  if mag >= self.actor.movementSpeed * 0.250 then -- snap if distance is further than 250ms to reach
    self.actor.x = playerData.x
    self.actor.y = playerData.y
  end

  self.targetX = playerData.x
  self.targetY = playerData.y
  self.targetFaceX = playerData.faceX
  self.targetFaceY = playerData.faceY
end

networkPlayer.update = function(self, dt)
  local actor = self.actor
  local moveSpeed = actor.movementSpeed * dt

  local dx = self.targetX - actor.x
  local dy = self.targetY - actor.y
  local mag = math.sqrt(dx^2 + dy^2)

  if mag > 0.01 then
    local dirX = dx / mag
    local dirY = dy / mag
    local moveDistance = math.min(moveSpeed, mag)
    actor.x = actor.x + dirX * moveDistance
    actor.y = actor.y + dirY * moveDistance
    actor.moveX = dirX
    actor.moveY = dirY
  else
    actor.x = self.targetX
    actor.y = self.targetY
    actor.moveX = 0
    actor.moveY = 0
  end

  local currentAngle = math.atan2(actor.faceY, actor.faceX)
  local targetAngle = math.atan2(self.targetFaceY, self.targetFaceX)

  local angleDiff = targetAngle - currentAngle
  if angleDiff > math.pi then
    angleDiff = angleDiff - 2 * math.pi
  elseif angleDiff < -math.pi then
    angleDiff = angleDiff + 2 * math.pi
  end

  local turnSpeed = 12 * dt
  local rotatedAngle = currentAngle + math.min(turnSpeed, math.max(-turnSpeed, angleDiff))

  actor.faceX = math.cos(rotatedAngle)
  actor.faceY = math.sin(rotatedAngle)

  actor:update(dt, true)
end

networkPlayer.draw = function(self)
  return self.actor
end

return networkPlayer