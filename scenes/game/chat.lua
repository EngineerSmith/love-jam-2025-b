local chat = {
  messages = { },
  maxMessages = 10,
  cursorPos = 0,
}

local ui = require("util.ui")

local utf8 = require("utf8")
local function split(str, pos) -- taken from suit.input
  local offset = utf8.offset(str, pos) or 0
  return str:sub(1, offset-1), str:sub(offset)
end

local networkClient = require("network.client")

local cb_chatMessage = function(message, owner)
  table.insert(chat.messages, {
    message = message,
    owner = owner,
    received = love.timer.getTime(),
  })
  if #chat.messages > chat.maxMessages then
    table.remove(chat.messages, 1)
  end
end

chat.load = function()
  networkClient.addHandler("chatMessage", cb_chatMessage)
  
  chat.messages = { }
  chat.input = ""
end

chat.unload = function()
  networkClient.removeHandler("chatMessage", cb_chatMessage)

  chat.messages = { }
end

local ownerColors = {
  ["you"] = { .7, 1, 1 },
  ["other"] = { 1, 1, 1 },
  ["server"] = { 1, 1, .5 },
}

local displayDuration, fadeDuration = 5, 2
chat.getMessageColor = function(message)
  local etime = love.timer.getTime() - message.received
  local c = message.owner and ownerColors[message.owner] or { 1, 1, 1 }
  if etime < displayDuration or chat.active then
    return c[1], c[2], c[3], 1
  elseif etime >= (displayDuration + fadeDuration) then
    return 1, 1, 1, 0
  else
    local progress = (etime - displayDuration) / fadeDuration
    return c[1], c[2], c[3], 1 - progress
  end
end

chat.setActive = function(isActive)
  isActive = isActive == true
  chat.active = isActive
  love.keyboard.setTextInput(isActive)

  chat.input = ""

  chat.keydown = nil
  chat.textchar = nil
  chat.candidate_text = nil
  chat.candidate_start = nil
  chat.candidate_length = nil
end

chat.resize = function(scale)
  chat.font = ui.getFont(14, "fonts.regular.bold", scale)
end

chat.update = function()
  if not chat.active then
    return
  end

  local input = chat.input or ""

  chat.cursor = math.max(1, math.min(utf8.len(input)+1, chat.cursor or utf8.len(input)+1))

  chat.cursorPos = 0
  if chat.cursor > 1 then
    local s = input:sub(1, utf8.offset(input, chat.cursor-1))
    chat.cursorPos = chat.font:getWidth(s)
  end
end

local lg = love.graphics
chat.draw = function()
  lg.push("all")
    local font = chat.font
    local lineHeight = font:getHeight()*1.1
    lg.translate(0, lg.getHeight()-lineHeight*2)
    if chat.active then
      lg.setColor(1,1,1,.1)
      lg.rectangle("fill", 0, lineHeight*1.5, lg.getWidth()/2,-lineHeight*chat.maxMessages)
    end
    lg.translate(font:getWidth(" "), 0)
    if chat.active then
      lg.setColor(1,1,1,1)
      lg.print(chat.input, font)
      if love.timer.getTime() % 1 > .5 then
        lg.setLineWidth(1)
        lg.setLineStyle("rough")
        lg.line(chat.cursorPos, 0,
                chat.cursorPos, font:getHeight())
      end
    end
    lg.translate(0, -lineHeight)
    lg.push()
    for i = #chat.messages, 1, -1 do
      local message = chat.messages[i]
      lg.setColor(chat.getMessageColor(message))
      lg.print(message.message, font, 0, 0)
      lg.translate(0, -lineHeight)
    end
    lg.pop()
  lg.pop()
end

chat.textinput = function(char)
  if not chat.active then
    return false
  end
  if char and char ~= "" then
    local a, b = split(chat.input, chat.cursor)
    chat.input = table.concat({a, char, b})
    chat.cursor = chat.cursor + utf8.len(char)
    return true
  end
  return false
end

chat.keypressed = function(_, scancode)
  if not chat.active then
    return false
  end

  if scancode == "v" and love.keyboard.isScancodeDown("lctrl", "rctrl") then
    scancode = "paste"
  end

  if scancode == "return" then
    local message = chat.input
    if message:find("%S") ~= nil then
      message = message:gsub("^%s*(.-)%s*$", "%1")
      networkClient.send("chatMessage", message)
    end
    chat.setActive(false)
    return true
  elseif scancode == "backspace" then
    local a, b = split(chat.input, chat.cursor)
    chat.input = table.concat({split(a, utf8.len(a)), b})
    chat.cursor = math.max(1, chat.cursor-1)
    return true
  elseif scancode == "delete" then
    local a, b = split(chat.input, chat.cursor)
    local _, b = split(b, 2)
    chat.input = table.concat(a, b)
    return true
  elseif scancode == "paste" then
    local a, b = split(chat.input, chat.cursor)
    local clipboard = love.system.getClipboardText()
    chat.input = table.concat({a, clipboard, b})
    chat.cursor = chat.cursor + utf8.len(clipboard)
    return true
  elseif scancode == "left" then
    chat.cursor = math.max(0, chat.cursor-1)
    return true
  elseif scancode == "right" then
    chat.cursor = math.min(utf8.len(chat.input)+1, chat.cursor+1)
    return true
  elseif scancode == "home" then
    chat.cursor = 1
    return true
  elseif scancode == "end" then
    chat.cursor = utf8.len(chat.input)+1
    return true
  end
  return false
end

return chat