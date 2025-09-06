local lg = love.graphics

local sceneManager = require("util.sceneManager")
local audioManager = require("util.audioManager")
local assetManager = require("util.assetManager")
local settings = require("util.settings")
local options = require("util.option")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local flux = require("libs.flux")
local enum = require("util.enum")
local ui = require("util.ui")
audioManager.setVolumeAll()

local networkClient = require("network.client")

local robotActor = require("assets.sprites.character.robot"):createActor()
local player = require("src.player")
player.new(robotActor)

local networkManager = require("src.networkManager")

local scene = { }
local chat = require("scenes.game.chat")

local currentPingValue = -1
local cb_ping = function(pingTime)
  currentPingValue = pingTime
end

local cb_disconnect = function(reason, code)
  cursor.switch(nil)
  sceneManager.changeScene("scenes.mainmenu", "disconnected")
end

--[[

TODO

[-] Add disconnect CB, change to main menu, with scene.menu = "connecting" and it should auto display the DC message

[skipped] Add Player list for who is in the room

[/] Add Player Chat

[/] Add Player Movement

[-] Add Player assets -- todo more, and actual animations

[ ] Add UI for changing character - maybe just set the four players to fixed colours? KISS

[ ] Add Ready buttons

[ ] Add count down to start game

[ ] Add game :sweat:
]]

scene.load = function(roomInfo)
  networkClient.addHandler("ping", cb_ping)
  networkClient.addHandler("disconnect", cb_disconnect)

  networkManager.load(roomInfo)
  chat.load()

  -- Load/keep loaded the main menu to return for disconnect
  sceneManager.preload("scenes.mainmenu")
end

scene.unload = function()
  networkClient.removeHandler("ping", cb_ping)
  networkClient.removeHandler("disconnect", cb_disconnect)

  networkManager.unload()
  chat.unload()

  networkClient.close()
end

scene.resize = function(w, h)
  -- Update settings
  settings.client.resize(w, h)

-- Scale scene
  local wsize = settings._default.client.windowSize
  local tw, th = wsize.width, wsize.height
  local sw, sh = w / tw, h / th
  scene.scale = sw < sh and sw or sh

  -- scale Text
  local font = ui.getFont(18, "fonts.regular.bold", scene.scale)
  lg.setFont(font)

  -- scale Cursor
  cursor.setScale(scene.scale)
  --
  chat.resize(scene.scale)
end

scene.update = function(dt)
  networkClient.threadErrorChecker()

  chat.update()

  player.update(dt)
  networkManager.update(dt)
end

scene.updateNetwork = function()
  if not networkClient.isConnected() then
    return
  end
  player.updateNetwork()
end

local sort_renderQueue = function(a, b)
  return (a.getDrawY and a:getDrawY() or a.y) < b.y
end

scene.draw = function()
  love.graphics.clear()

  local renderQueue = { }

  networkManager.draw(renderQueue)
  table.insert(renderQueue, player.draw())

  table.sort(renderQueue, sort_renderQueue)
  for _, render in ipairs(renderQueue) do
    render:draw()
  end

  lg.push("all")
    local font = ui.getFont(12, "fonts.regular.bold", scene.scale)
    lg.setColor(.5,.5,.5,1)
    lg.print("Ping: "..(currentPingValue).."ms", font, 0, 0)
  lg.pop()
  chat.draw()
end

scene.textinput = function(...)
  chat.textinput(...)
end

scene.keypressed = function(_, scancode, ...)
  if scancode == "escape" and chat.active then
    chat.setActive(false)
    return -- consumed
  elseif scancode == "return" and not chat.active then
    chat.setActive(true)
    return -- consumed
  end
  if chat.keypressed(_, scancode, ...) then
    return -- consumed
  end
end

scene.joystickadded = function(...)
  input.joystickadded(...)
end

scene.joystickremoved = function(...)
  input.joystickremoved(...)
end

scene.gamepadpressed = function(...)
  input.gamepadpressed(...)
end

return scene