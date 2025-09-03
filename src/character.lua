local character = { }
character.__index = character

local lg = love.graphics

local logger = require("util.logger")

local directionMap = {
  { name = "South East",       angle = 315.0 },
  { name = "South South East", angle = 337.5 },
  { name = "South",            angle =   0.0 }, -- 360.0
  { name = "South South West", angle =  22.5 },
  { name = "South West",       angle =  45.0 },
  { name = "South West West",  angle =  67.5 },
  { name = "West",             angle =  90.0 },
  { name = "North West West",  angle = 112.5 },
  { name = "North West",       angle = 135.0 },
  { name = "North North West", angle = 157.5 },
  { name = "North",            angle = 180.0 },
  { name = "North North East", angle = 202.5 },
  { name = "North East",       angle = 225.0 },
  { name = "North East East",  angle = 247.5 },
  { name = "East",             angle = 270.0 },
  { name = "South East East",  angle = 292.5 },
}

local getDirectionFromVector = function(vx, vy)
  if vx == 0 and vy == 0 then
    return nil
  end

  local angle = (math.atan2(vy, vx) * (180 / math.pi) + 270.0 + 360.0) % 360.0
  local closestIndex = 0
  local minDifference = 360
  for i, data in ipairs(directionMap) do
    local diff = math.abs(angle - data.angle)
    if diff > 180 then
      diff = 360 - diff
    end
    if diff < minDifference then
      minDifference = diff
      closestIndex = i
    end
  end
  return closestIndex == 0 and nil or closestIndex
end

-- 1 -> _01.png; 12 -> _12.png
local getFileNameFromNumber = function(num)
  return ("_%02d.png"):format(num)
end

local loadStateSprites = function(path)
  local frameDirectories = love.filesystem.getDirectoryItems(path)
  local frameCount = #frameDirectories
  local sprites = { }
  for frame = 1, frameCount do
    local frames = { }
    sprites[frame] = frames
    local framePath = path .. tostring(frame-1) .. "/"
    for direction = 1, 16 do
      local directionPath = framePath .. getFileNameFromNumber(direction-1)
      frames[direction] = love.graphics.newImage(directionPath)
    end
  end
  return sprites
end

character.new = function(name, path, states)
  local loadedStates = { }
  for i, animation in ipairs(states) do
    local newState = loadStateSprites(path .. animation.name .. "/")
    newState.speed = animation.speed
    loadedStates[animation.name] = newState
  end
  return setmetatable({
    name = name or "UNKNOWN",
    states = loadedStates,
  }, character)
end

character.createActor = function(self)
  local actor = require("src.actor")
  return actor.new(self)
end

character.getStateFrameInfo = function(self, state)
  if not state or not self.states[state] then
    return nil
  end
  return {
    frameCount = #self.states[state],
    speed = self.states[state].speed,
  }
end

character.draw = function(self, faceX, faceY, state, frame)
  faceX = faceX or 0
  faceY = faceY or 0
  state = state or ""
  frame = frame or 0

  local stateFrames = self.states[state]
  if not stateFrames then
    logger.warn("Tried to draw "..self.name.." but doesn't have given state: "..state)
    return
  end

  local frameDirections = stateFrames[frame]
  if not frameDirections then
    logger.warn("PRIRIF ctrl+f") -- shouldn't hit here, but add an error message so we can find the issue
    return
  end

  local directionIndex = getDirectionFromVector(faceX, faceY)
  local sprite = frameDirections[directionIndex]
  if not sprite then
    logger.warn("adzejffg ctrl+f") -- shouldn't hit here, but add an error message so we can find the issue
    return
  end
  lg.draw(sprite, 0, 0, 0, 1, 1, sprite:getWidth()/2, sprite:getHeight()/2)
end

return character
