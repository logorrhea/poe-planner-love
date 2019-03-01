local searchbox = {
  name = 'Search Box',
  data = {text = '', prevtext = '', cursor = false},
  options = {font = headerFont},
  padding = love.window.toPixels(10),
  -- dims = vec(0, love.window.toPixels(30)),
  -- maxDims = vec(love.window.toPixels(200), love.window.toPixels(30)),
  dims = vec(0, 30),
  maxDims = vec(200, 30),
  state = 'inactive',
  matches = {
    regular = {},
    ascendancy = {},
  }
}

function searchbox:init()
  self:resize()
  self:blinkTimer()

  -- Init icons
  self.icons = {}

  -- Search icon
  self.icons.search = {
    id = 'search-open',
    default = love.graphics.newImage('icons/search_default.png'),
    hover = love.graphics.newImage('icons/search_hovered.png'),
    active = love.graphics.newImage('icons/search_active.png'),
  }

  -- Close icon
  self.icons.close = {
    id = 'search-close',
    default = love.graphics.newImage('icons/delete_default.png'),
    hovered = love.graphics.newImage('icons/delete_hovered.png'),
    active = love.graphics.newImage('icons/delete_active.png'),
  }
end

function searchbox:update(dt)
  if self.data.prevtext ~= self.data.text then
    self:resetTimers()
  end
  self.data.prevtext = self.data.text
end

function searchbox:draw()

  if self.state ~= 'inactive' then

    -- Need icon dimensions for drawing the search box
    local w, h = self.icons.close.default:getDimensions()
    w = love.window.toPixels(w)
    h = love.window.toPixels(h)

    -- Black box
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    local x = self.pos.x - w + (self.maxDims.x - self.dims.x)
    love.graphics.rectangle('fill', x, self.pos.y, self.dims.x, self.dims.y)

    -- Search text
    -- Use scissor to limit width of text to width of the text box
    clearColor()
    if self.dims.x > 0 then
      love.graphics.setScissor(x, self.pos.y, self.dims.x, self.dims.y)
    end
    local text = self.data.text
    if self.cursor == true and self:isFocused() then
      text = text .. '_'
    end
    love.graphics.print(text, x + self.padding/2, self.pos.y+self.padding/2)
    love.graphics.setScissor()

    if suit.ImageButton(self.icons.close.default, {hovered=self.icons.close.hovered, active=self.icons.close.active}, winWidth - self.padding - w, winHeight - self.padding - h).hit then
      self:hide()
    end
  else
    local w, h = self.icons.search.default:getDimensions()
    w = love.window.toPixels(w)
    h = love.window.toPixels(h)
    if suit.ImageButton(self.icons.search.default, {hovered=self.icons.search.hovered, active=self.icons.search.active}, winWidth - self.padding - w, winHeight - self.padding - h).hit then
      self:show()
    end
  end
end

function searchbox:click(x, y)
  if x > self.pos.x and x < self.pos.x + self.dims.x and y > self.pos.y and y < self.pos.y + self.dims.y then
    self.state = 'focused'
    return true
  else
    -- self.state = 'inactive'
    if self.state ~= 'inactive' then
      self.state = 'active'
    end
    return false
  end
end

function searchbox:show()
  if self.state == 'opening' or self.state == 'focused' then return false end
  if self.state == 'active' then
    self.state = 'focused'
    return true
  end

  self.state = 'opening'
  Timer.tween(0.5, self.dims, {x = self.maxDims.x}, 'out-cubic', function()
    self.state = 'focused'
  end)
end

function searchbox:hide()
  self.state = 'closing'
  Timer.tween(0.5, self.dims, {x = 3}, 'out-cubic', function()
    -- self.data.text = ''
    self.state = 'inactive'
  end)
end

function searchbox:isActive()
  return self.state ~= 'inactive'
end

function searchbox:isFocused()
  return self.state == 'focused'
end

function searchbox:isExclusive()
  return false
end

function searchbox:textinput(t)
  self:resetTimers()
  self.data.text = self.data.text..t
end

function searchbox:backspace()
  self:resetTimers()
  self.data.text = self.data.text:sub(1, -2)
end

function searchbox:resetTimers()
  if self.timer ~= nil then Timer.cancel(self.timer) end
  self.cursor = false
  self.timer = Timer.after(0.3, function()
    self:searchNodes()
    self:blinkTimer()
  end)
end

function searchbox:searchNodes()
  local rmatches = {}
  local amatches = {}
  local search = string.lower(self.data.text)
  if string.len(search) == 0 then goto nodeloopend end

  for _, node in ipairs(Tree.nodes) do
    local nid = tonumber(node.id)
    local node = nodes[nid]
    local title = string.lower(node.name)
    if not node:isMastery() then
      if title:match(search) ~= nil then
        if node:isAscendancy() then
          amatches[#amatches+1] = nid
        else
          rmatches[#rmatches+1] = nid
        end
      else
        for _, description in ipairs(node.descriptions) do
          local desc = string.lower(description)
          if desc:match(search) ~= nil then
            if node:isAscendancy() then
              amatches[#amatches+1] = nid
            else
              rmatches[#rmatches+1] = nid
            end
            goto breakloop
          end
        end
        ::breakloop::
      end
    end
  end
  ::nodeloopend::

  self.matches.regular = rmatches
  self.matches.ascendancy = amatches
end

function searchbox:getMatches(type)
  return self.matches[type] or {}
end

function searchbox:blinkTimer()
  if self.timer ~= nil then Timer.cancel(self.timer) end
  self.timer = Timer.every(0.5, function()
    self.cursor = not self.cursor
  end)
end

function searchbox:resize()
  self.pos = vec(winWidth - self.padding - self.maxDims.x, winHeight - self.padding - self.maxDims.y)
end

return searchbox
