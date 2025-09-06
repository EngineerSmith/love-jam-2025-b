local networkProjectile = require("src.networkProjectile")

local sprite = love.graphics.newImage("assets/sprites/projectile/player/projectile.png")
local playerProjectile = networkProjectile.new("player", 500, sprite)

return playerProjectile