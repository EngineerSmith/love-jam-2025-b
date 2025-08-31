local lg = love.graphics

local audioManager = require("util.audioManager")
local assetManager = require("util.assetManager")
local settings = require("util.settings")
local options = require("util.option")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local flux = require("libs.flux")
local suit = require("libs.suit").new()
local enum = require("util.enum")
local ui = require("util.ui")

local background = require("scenes.mainmenu.background")

require("network")
local networkClient = require("network.client")

local settingsMenu = require("ui.menu.settings")
settingsMenu.set(suit)

suit.theme = require("ui.theme.menu")

local username_adjectives = {
  "Jolly", "Mystic", "Cosmic", "Fiery", "Slippery",
  "Whimsical", "Shadow", "Spooky", "Electric", "Galactic",
  "Blazing", "Speedy", "Rusty", "Gilded", "Velvet",
  "Crystal",  "Mighty", "Wandering", "Giggling", "Sneaky",
  "Cuddly", "Silent", "Bouncing", "Quirky", "Frosty",
  "Emerald", "Glowing", "Obsidian", "Chaotic", "Daring",
  "Grumpy", "Soft", "Eager", "Valiant", "Dizzy",
  "Hungry", "Nimble", "Golden", "Stealthy", "Dusty",
  "Roaring", "Whispering", "Thunder", "Breezy", "Silky",
  "Ancient", "Flying", "Silver", "Brave", "Jazzy",
}
local username_nouns = {
  "Wombat", "Mantis", "Potato", "Otter", "Bandit",
  "Warlock", "Spectre", "Panda", "Robot", "Dragon",
  "Falcon", "Comet", "Wizard", "Badger", "Goblin",
  "Knight", "Pirate", "Sphinx", "Squirrel", "Ninja",
  "Fox", "Phoenix", "Ghost", "Kraken", "Muffin",
  "Serpent", "Duck", "Turtle", "Jellyfish", "Koala",
  "Puffin", "Chameleon", "Dolphin", "Vulture", "Mongoose",
  "Rhino", "Panther", "Scorpion", "Yeti", "Chimera",
  "Dog", "Penguin", "Mammoth", "Walrus", "Sloth",
  "Cyborg", "Unicorn", "Sasquatch", "Lemur", "Golem",
}

function get_username()
  local username
  for i=1, 5 do
    username = username_adjectives[love.math.random(#username_adjectives)] .. username_nouns[love.math.random(#username_nouns)]
    if options.validateUsername(username) then
      break
    end
    username = ""
  end
  return username
end

local scene = {
  username = { text = get_username() or "" },
  usernameOpt = {
    color = { normal = { .7,.7,1,.05 } },
  },
  server = { text = "127.0.0.1" },
  serverOpt = {
    color = { normal = { .7,.7,1,.05 } },
  },
  roomKey = { text = "" },
  roomKeyOpt = {
    color = { normal = { .7,.7,1,.05}}
  }
}

scene.preload = function()
  settingsMenu.preload()
end

--- networking CBs

local cb_connected = function()
  networkClient.login(scene.username.text)
end

local cb_login = function()
  logger.warn("Logged in, you mad man")
   scene.menu = "joinroom"
  cursor.switch(nil)
end

local currentPingValue = 0
local cb_ping = function(pingTime)
  currentPingValue = pingTime
end

---

scene.load = function()
  suit:gamepadMode(true)
  cursor.setType(settings.client.systemCursor and "system" or "custom")

  scene.menu = "prompt"
  settingsMenu.load()
  background.load()

  networkClient.addHandler(enum.packetType.connected, cb_connected)
  networkClient.addHandler(enum.packetType.login, cb_login)
  networkClient.addHandler("ping", cb_ping)

  currentPingValue = 0
end

scene.unload = function()
  cursor.switch(nil)
  settingsMenu.unload()
  background.unload()

  networkClient.removeHandler(enum.packetType.connected, cb_connected)
  networkClient.removeHandler(enum.packetType.login, cb_login)
  networkClient.removeHandler("ping", cb_ping)

  currentPingValue = 0
end

scene.langchanged = function()
  scene.prompt = require("libs.sysl-text").new("left", { 
    color = { 1,1,1,1 },
  })
  scene.prompt:send(lang.getText("menu.prompt"), nil, true)
end

scene.resize = function(w, h)
  -- Update settings
  settings.client.resize(w, h)

-- Scale scene
  local wsize = settings._default.client.windowSize
  local tw, th = wsize.width, wsize.height
  local sw, sh = w / tw, h / th
  scene.scale = sw < sh and sw or sh

  -- scale UI
  suit.scale = scene.scale
  suit.theme.scale = scene.scale

  -- scale Text
  local font = ui.getFont(18, "fonts.regular.bold", scene.scale)
  lg.setFont(font)

  scene.prompt.default_font = font

  -- scale Cursor
  cursor.setScale(scene.scale)

  -- scale Background
  background.resize(w, h, scene.scale)
end

local inputTimer, inputTimeout = 0, 0
local inputType = nil
scene.update = function(dt)
  networkClient.threadErrorChecker()

  background.update(dt, scene.scale)

  if scene.menu == "main" then
    if not suit.gamepadActive then
      if input.baton:pressed("menuNavUp") or input.baton:pressed("menuNavDown") then
        suit:gamepadMode(true)
      end
    end
    if suit.gamepadActive then
      if not inputType then
        local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
        local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
        local pos = menuUp - menuDown
        if pos ~= 0 then
          inputType = pos == 1 and "menuNavUp" or "menuNavDown"
          inputTimer = 0
          inputTimeout = .5
        end

        suit:adjustGamepadPosition(pos)
      else
        if input.baton:released(inputType) then
          inputType = nil
        else
          inputTimer = inputTimer + dt
          while inputTimer > inputTimeout do
            inputTimer = inputTimer - inputTimeout
            inputTimeout = .1
            suit:adjustGamepadPosition(inputType == "menuNavUp" and 1 or -1)
          end
        end
      end

      if input.baton:pressed("accept") then
        suit:setHit(suit.hovered)
      end
      if input.baton:pressed("reject") then
        suit:setGamepadPosition(1) -- jump to exit button
      end
    end
  end

  if suit.gamepadActive then
    love.mouse.setRelativeMode(true)
    love.mouse.setVisible(false)
  else
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(true)
  end

  if scene.menu == "settings" then
    settingsMenu.update(dt)
  end

  scene.prompt:update(dt)
end

local maxOffsetW = 30

local drawMenuButton = function(text, opt, x, y, w, h)
  local slice3 = assetManager["ui.3slice.basic"]

  if opt.entered then
    if opt.flux then opt.flux:stop() end
    opt.flux = flux.to(opt, .5, {
      offsetW = maxOffsetW
    }):ease("elasticout")
  end
  if opt.left then
    if opt.flux then opt.flux:stop() end
    opt.flux = flux.to(opt, .2, {
      offsetW = 0
    }):ease("quadout")
  end
  if not opt.hovered and opt.flux and opt.flux.progress >= 1 then
    opt.flux:stop()
    opt.flux = nil
    opt.offsetW = 0
  end

  lg.push()
  lg.origin()
  lg.translate(x, y)
    lg.push() 
    if opt.hovered then
      lg.setColor(1,1,1,1)
    else
      lg.setColor(1,1,1,1)
    end
    slice3:draw(lg.getFont():getWidth(text) + (slice3.offset*2 + opt.offsetW) * scene.scale, h)
    lg.pop()
  lg.setColor(.1,.1,.1,1)
  if opt.hovered then
    text = " "..text
  end
  lg.print(text, slice3.offset * scene.scale, 0)
  lg.setColor(1,1,1,1)
  lg.pop()
end

local changeMenu = function(target)
  scene.menu = target
  cursor.switch(nil)
end

local menuButton = function(button, font, height)
  local str = lang.getText(button.id)
  local slice3 = assetManager["ui.3slice.basic"]
  local slice3Width = slice3:getLength(font:getWidth(str), height)
  local width = slice3Width + maxOffsetW * scene.scale
  local b = suit:Button(str, button, suit.layout:up(width, nil))
  if b.hit and type(button.hitCB) == "function" then
    audioManager.play("audio.ui.click")
    button.hitCB()
    return
  end
  cursor.switchIf(b.hovered, "hand")
  cursor.switchIf(b.left, nil)

  if b.entered then
    audioManager.play("audio.ui.select")
  end
end

local mainButtonFactory = function(langKey, callback)
  return {
    id = langKey,
    hitCB = callback,
    noScaleX = true,
    draw = drawMenuButton,
    gamepadOption = true,
    offsetW = 0,
  }
end

local mainButtons = {
  mainButtonFactory("menu.exit", function()
      love.event.quit()
    end),
  mainButtonFactory("menu.settings", function()
      changeMenu("settings")
      suit:setGamepadPosition(1)
    end),
  mainButtonFactory("menu.new_game", function()
      changeMenu("game")
      suit:setGamepadPosition(1)
      --sceneManager.changeScene("scenes.game")
    end),
}

local __BACKBUTTON = mainButtonFactory("menu.back", function()
  if scene.menu == "connecting" or scene.menu == "joinroom" then
    if networkClient.state == "loggedIn" then
      networkClient.close()
    end
    changeMenu("game")
  else
    changeMenu("main")
  end
  suit:setGamepadPosition(1)
end)

if false then
  logger.warn("TODO load button conditional show")
  table.insert(mainButtons,
    mainButtonFactory("menu.load", function()
      logger.warn("TODO load game button")
    end))
  table.insert(mainButtons,
    mainButtonFactory("menu.continue", function()
      logger.warn("TODO continue game button")
    end))
end

scene.updateui = function()
  suit:enterFrame()
  local font = lg.getFont()
  local fontHeight = font:getHeight()
  local buttonHeight = fontHeight / scene.scale

  local windowHeightScaled = lg.getHeight() / scene.scale
  suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 10)
  suit.layout:up(0, buttonHeight)
  suit.layout:up(0, buttonHeight)

  if scene.menu == "main" then
    for _, button in ipairs(mainButtons) do
      menuButton(button, font, buttonHeight)
    end
  elseif scene.menu == "settings" then
    if settingsMenu.updateui() then
      changeMenu("main")
    end
  elseif scene.menu == "connecting" then
    if networkClient.state == "disconnected" then
      suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 0)
      suit.layout:up(0, buttonHeight)
      menuButton(__BACKBUTTON, font, buttonHeight)
    end
  elseif scene.menu == "joinroom" then
    suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 0)
    suit.layout:up(0, buttonHeight)
    menuButton(__BACKBUTTON, font, buttonHeight)
    --
    local windowSize = settings._default.client.windowSize
    local offsetWidth = math.floor((lg.getWidth()/suit.scale - windowSize.width) / 2)
    local _tempX, _tempY, padX = 300, 35, 30
    suit.layout:reset(offsetWidth+windowSize.height/8+200, windowSize.height/8/0.6+_tempY*2, padX, 10)

    -- Room Key
    local joinRoomButton = false
    if scene.roomKey.length == 4 and scene.roomKey.text:match("%d%d%d%d") then
      scene.roomKeyOpt.boarder = { 0.1, 0.6, 0.3, 1 }
      joinRoomButton = false
    else
      scene.roomKeyOpt.boarder = nil
      joinRoomButton = true
    end

    scene.roomKeyOpt.font = font
    local i = suit:Input(scene.roomKey, scene.roomKeyOpt, suit.layout:down(_tempX, _tempY))
    cursor.switchIf(i.hovered, "hand")
    cursor.switchIf(i.left, nil)
    if scene.roomKeyOpt.hasKeyboardFocus then
      love.keyboard.setTextInput(true)
      whoSetTextInput = scene.roomKeyOpt
    elseif love.keyboard.hasTextInput() and whoSetTextInput == scene.roomKeyOpt then -- not scene.roomKeyOpt.hasKeyboardFocus
      love.keyboard.setTextInput(false)
    end

    local n = font:getWidth("Room Code") * 1.1
    suit:Label("Room Code", { font = font, align = "right" }, suit.layout:left(n, _tempY))
    suit.layout:translate(n+padX, 10)

    -- Join room button
    suit.layout:translate(50, 0)
    local b = suit:Button("Join Room", { font = font, color = {  }, disable = joinRoomButton }, suit.layout:down(_tempX/1.5, _tempY))
    cursor.switchIf(b.hovered, "hand")
    cursor.switchIf(b.left, nil)
    if b.hit then
      -- changeMenu("connecting")
      -- networkClient.connect(scene.server.text)
    end

    if b.entered then
      audioManager.play("audio.ui.select")
    end

  elseif scene.menu == "game" then
    suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 0)
    suit.layout:up(0, buttonHeight)
    menuButton(__BACKBUTTON, font, buttonHeight)
    --
    local windowSize = settings._default.client.windowSize
    local offsetWidth = math.floor((lg.getWidth()/suit.scale - windowSize.width) / 2)
    local _tempX, _tempY, padX = 300, 35, 30
    suit.layout:reset(offsetWidth+windowSize.height/8+200, windowSize.height/8/0.6+_tempY*2, padX, 10)

    -- Username
    local connectButtonDisabled = false
    if options.validateUsername(scene.username.text) then
      scene.usernameOpt.boarder = { 0.1, 0.6, 0.3, 1 }
      connectButtonDisabled = false
    else
      scene.usernameOpt.boarder = { 0.6, 0.1, 0.1, 1 }
      connectButtonDisabled = true
    end

    scene.usernameOpt.font = font
    local i = suit:Input(scene.username, scene.usernameOpt, suit.layout:down(_tempX, _tempY))
    cursor.switchIf(i.hovered, "hand")
    cursor.switchIf(i.left, nil)
    if scene.usernameOpt.hasKeyboardFocus then
      love.keyboard.setTextInput(true)
      whoSetTextInput = scene.usernameOpt
    elseif love.keyboard.hasTextInput() and whoSetTextInput == scene.usernameOpt then -- not scene.usernameOpt.hasKeyboardFocus
      love.keyboard.setTextInput(false)
    end

    local n = font:getWidth("Username") * 1.1
    suit:Label("Username", { font = font, align = "right" }, suit.layout:left(n, _tempY))
    suit.layout:translate(n+padX, 10)

    -- Connect button
    suit.layout:translate(70, 0)
    local b = suit:Button("Connect", { font = font, color = {  }, disable = connectButtonDisabled }, suit.layout:down(_tempX/2, _tempY))
    cursor.switchIf(b.hovered, "hand")
    cursor.switchIf(b.left, nil)
    if b.hit then
      -- connect
      changeMenu("connecting")
      networkClient.connect(scene.server.text)
    end

    if b.entered then
      audioManager.play("audio.ui.select")
    end

    -- Server address
    suit.layout:reset(offsetWidth+windowSize.height/8+200, windowHeightScaled - _tempY*3, padX, 10)
    scene.serverOpt.font = font
    local i = suit:Input(scene.server, scene.serverOpt, suit.layout:up(_tempX, _tempY))
    cursor.switchIf(i.hovered, "hand")
    cursor.switchIf(i.left, nil)
    if scene.serverOpt.hasKeyboardFocus then
      love.keyboard.setTextInput(true)
      whoSetTextInput = scene.serverOpt
    elseif love.keyboard.hasTextInput() and whoSetTextInput == scene.serverOpt then -- not scene.serverOpt.hasKeyboardFocus
      love.keyboard.setTextInput(false)
    end

    local n = font:getWidth("Server") * 1.1
    suit:Label("Server", { font = font, align = "right" }, suit.layout:left(n, _tempY))
    suit.layout:translate(n+padX, 10)

  end
end

scene.draw = function()
  lg.clear(0/255, 0/255, 0/255)
  background.draw(scene.scale)
  if scene.menu == "prompt" then
    local windowW, windowH = lg.getDimensions()
    local offset = windowH/10
    scene.prompt:draw(offset, windowH - offset - scene.prompt.get.height)
  elseif scene.menu == "settings" or scene.menu == "game" or scene.menu == "connecting" or scene.menu == "joinroom" then
    settingsMenu.draw()
  end
  if scene.menu == "joinroom" or (scene.menu == "connecting" and networkClient.state == "loggedIn") then
    lg.push("all")
    local font = ui.getFont(14, "fonts.regular.bold", scene.scale)
    lg.setColor(.5,.5,.5,1)
    lg.print("Ping: "..currentPingValue, font, 0, 0)
    lg.pop()
  end
  if scene.menu == "connecting" then
    -- print(networkClient.state)
    local font = lg.getFont()
    local fontHeight = font:getHeight()

    local text = "Disconnected"
    if networkClient.state == "pending" or networkClient.state == "connected" then
      text = "Connecting..."
    elseif networkClient.state == "loggedIn" then
      text = "Connected"
    elseif networkClient.state == "disconnected" then
      text = "Disconnected"
    end
    local len = font:getWidth(text)
    lg.print(text, font, lg.getWidth()/2-len/2, lg.getHeight()/2-fontHeight/2)
    if networkClient.state == "disconnected" and networkClient.lastDisconnectReason then
      local text = networkClient.lastDisconnectReason
      local len = font:getWidth(text)
      lg.print(text, font, lg.getWidth()/2-len/2, lg.getHeight()/2+fontHeight/2*2)
    end
  end
  suit:draw(1)
end

scene.textedited = function(...)
  suit:textedited(...)
end

scene.textinput = function(...)
  suit:textinput(...)
end

local inputDetected = function(inputType)
  if scene.menu == "prompt" then
    flux.to(scene.prompt.current_color, .2, { [4] = 0 }):ease("linear"):oncomplete(function()
      changeMenu("main")
    end)
    if inputType == "mouse" then
      suit:gamepadMode(false)
    end
  end
end

scene.keypressed = function(...)
  suit:keypressed(...)
  inputDetected()
end

scene.mousepressed = function()
  inputDetected("mouse")
  suit:gamepadMode(false)
end
scene.touchpressed = scene.mousepressed

scene.mousemoved = function()
  if scene.menu ~= "prompt" then
    suit:gamepadMode(false)
  end
end

scene.wheelmoved = function(...)
  suit:updateWheel(...)
  inputDetected()
end

scene.gamepadpressed = function()
  inputDetected()
  suit:gamepadMode(true)
end
scene.joystickpressed = scene.gamepadpressed
scene.joystickaxis = scene.gamepadpressed

return scene