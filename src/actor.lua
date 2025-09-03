local actor = { }
actor.__index = actor

local lg = love.graphics

actor.new = function(character)
  return setmetatable({
    character = character,
    x = 0,
    y = 0,
    moveX = 0,
    moveY = 0,
    faceX = 0,
    faceY = 1, -- default facing direction, South
    movementSpeed = 100, -- default 100 pixels/sec
    state = "stand",
    currentFrame = 1,
    animationTimer = 0,
  }, actor)
end

-- Used for pooled actors
actor.reset = function(self)
  self.x = 0
  self.y = 0
  self.moveX = 0
  self.moveY = 0
  self.faceX = 0
  self.faceY = 1
  self:setState("stand")
end

actor.setMoveVector = function(self, moveX, moveY)
  local mag = math.sqrt(moveX^2 + moveY^2)
  if mag ~= 0 then
    moveX = moveX / mag
    moveY = moveY / mag
  end
  self.moveX = moveX
  self.moveY = moveY
end

actor.setFacingVector = function(self, faceX, faceY)
  local mag = math.sqrt(faceX^2 + faceY^2)
  if mag ~= 0 then
    faceX = faceX / mag
    faceY = faceY / mag
    self.faceX = faceX
    self.faceY = faceY
  end
end

actor.attack = function(self)
  self:setState("attack")
end

actor.setState = function(self, newState)
  self.state = newState
  self.currentFrame = 1
  self.animationTimer = 0
end

actor.update = function(self, dt, notUpdatePosition)
  if not notUpdatePosition then
    self.x = self.x + self.moveX * self.movementSpeed * dt
    self.y = self.y + self.moveY * self.movementSpeed * dt
  end

  self.animationTimer = self.animationTimer + dt
  local frameInfo = self.character:getStateFrameInfo(self.state)
  if frameInfo.frameCount > 1 then
    while self.animationTimer >= frameInfo.speed do
      self.animationTimer = self.animationTimer - frameInfo.speed
      self.currentFrame = self.currentFrame + 1
      if self.currentFrame > frameInfo.frameCount then
        if self.state == "attack" then
          if self.moveX == 0 and self.moveY == 0 then
            self:setState("stand")
          else
            self:setState("walk")
          end
        else
          self.currentFrame = 1
        end
      end
    end
  else
    self.currentFrame = 1
  end

  if self.state ~= "attack" then
    if self.moveX ~= 0 or self.moveY ~= 0 then
      self:setState("walk")
    else
      if self.state == "walk" and self.currentFrame == frameInfo.frameCount then
        self:setState("stand")
      end
    end
  end
end

actor.getDrawY = function(self)
  return self.y
end

actor.draw = function(self)
  lg.push()
  lg.translate(self.x, self.y)
  self.character:draw(self.faceX, self.faceY, self.state, self.currentFrame)
  lg.pop()
end

return actor