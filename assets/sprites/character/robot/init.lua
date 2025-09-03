local character = require("src.character")
local robotCharacter = character.new(
  "robot",
  "assets/sprites/character/robot/",
  {
    { name = "stand", speed = 0.2 },
    { name = "walk", speed = 0.2 },
    { name = "attack", speed = 0.2 },
  }
)

return robotCharacter