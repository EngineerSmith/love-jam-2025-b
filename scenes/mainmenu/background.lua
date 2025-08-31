local background = {
  backStars = { },
  frontStars = { },
  starSprites = { },
  backX = 0,
  frontX = 0,
  nebulaX = 0,
}

local lg = love.graphics

local assetManager = require("util.assetManager")

background.load = function()
  background.starSprites = {
    assetManager["sprite.menu.star.0"],
    assetManager["sprite.menu.star.1"],
    assetManager["sprite.menu.star.2"],
    assetManager["sprite.menu.star.3"],
    assetManager["sprite.menu.star.4"],
    assetManager["sprite.menu.star.5"],
    assetManager["sprite.menu.star.6"],
    assetManager["sprite.menu.star.7"],
    assetManager["sprite.menu.star.8"],
  }
  background.nebula = assetManager["sprite.menu.nebula"]
  background.backX = 0
  background.frontX = 0
  background.nebulaX = 0
end

background.unload = function()
  background.backStars = { }
  background.frontStars { }
  background.starSprites = { }
  background.backX = 0
  background.frontX = 0
  background.nebulaX = 0
end

background.resize = function(w, h, scale)
  background.backStars = { }
  for _ = 1, 30 + 30 * scale do
    table.insert(background.backStars, {
      x = love.math.random(-8*scale, w+8*scale*8),
      y = love.math.random(-8*scale, h+8*scale*8),
      sprite = love.math.random(#background.starSprites),
    })
  end
  background.frontStars = { }
  for _ = 1, 10 + 20 * scale do
    table.insert(background.frontStars, {
      x = love.math.random(-8*scale*2, w+8*scale*8*2),
      y = love.math.random(-8*scale*2, h+8*scale*8*2),
      sprite = love.math.random(#background.starSprites),
    })
  end
  background.nebulaX = w - background.nebula:getWidth()*scale*2*1.1
end

background.update = function(dt, scale)
  background.backX = background.backX + -15*scale * dt
  background.nebulaX =  background.nebulaX + -25*scale * dt
  background.frontX = background.frontX + -150*scale * dt

  local limit = -8*scale
  for _, star in ipairs(background.backStars) do
    local sprite = background.starSprites[star.sprite]
    if star.x + background.backX < limit - sprite:getWidth() then
      star.x = star.x + lg.getWidth()+8*scale*8
    end
  end

  if background.nebulaX < limit - background.nebula:getWidth() * 2 * scale then
    background.nebulaX = background.nebulaX + lg.getWidth() + background.nebula:getWidth() * 2 * scale
  end

  for _, star in ipairs(background.frontStars) do
    local sprite = background.starSprites[star.sprite]
    if star.x + background.frontX < limit - sprite:getWidth() * 2 then
      star.x = star.x + lg.getWidth()+8*scale*8*2
    end
  end
end

background.draw = function(scale)
  lg.push("all")
    lg.setColor(.3,.3,.3,1)
    lg.translate(math.floor(background.backX), 0)
    for _, star in ipairs(background.backStars) do
      local sprite = background.starSprites[star.sprite]
      local s = math.floor(1*math.max(1, scale*.8))
      lg.draw(sprite, star.x, star.y, 0, s, s, math.floor(sprite:getWidth()/2), math.floor(sprite:getHeight()/2))
    end
  lg.pop()
  lg.push("all")
    lg.setColor(.7,.7,.7,0.8)
    lg.draw(background.nebula, background.nebulaX, lg.getHeight()/2, 0, 2*scale, 2*scale, 0, background.nebula:getHeight()/2)
  lg.pop()
  lg.push("all")
    lg.setColor(1,1,1,1)
    lg.setBlendMode("add")
    lg.translate(math.floor(background.frontX), 0)
    for _, star in ipairs(background.frontStars) do
      local sprite = background.starSprites[star.sprite]
      local s = math.floor(1*math.max(1, scale*1.2))
      lg.draw(sprite, star.x, star.y, 0, s, s, math.floor(sprite:getWidth()/2), math.floor(sprite:getHeight()/2))
    end
  lg.pop()
end

return background