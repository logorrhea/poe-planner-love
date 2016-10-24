local searchbox = {
  name = 'Search Box',
  data = {text = ''},
  options = {font = headerFont},
  text = '',
  prevtext = '',
  padding = love.window.toPixels(10),
  dims = vec(0, love.window.toPixels(30)),
  maxDims = vec(love.window.toPixels(200), love.window.toPixels(30)),
  state = 'inactive',
  matches = {
    regular = {},
    ascendancy = {},
  }
}

function searchbox:init()
  self.pos = vec(winWidth - self.padding - self.maxDims.x, winHeight - self.padding - self.maxDims.y)
  self:blinkTimer()

  -- Init icons
  self.icons = {}

  -- Search icon
  local search = love.graphics.newImage('icons/search.png')
  local w, h = search:getDimensions()
  self.icons.search = {
    sheet = search,
    options = {
      id = 'search-open',
      normal = love.graphics.newQuad(0, 0, 32, 32, w, h),
      active = love.graphics.newQuad(32, 0, 32, 32, w, h),
      hovered = love.graphics.newQuad(32, 0, 32, 32, w, h),
    }
  }

  -- Close icon
  local close = love.graphics.newImage('icons/delete-button.png')
  w, h = close:getDimensions()
  self.icons.close = {
    sheet = close,
    options = {
      id = 'search-close',
      normal = love.graphics.newQuad(0, 0, 32, 32, w, h),
      active = love.graphics.newQuad(64, 0, 32, 32, w, h),
      hovered = love.graphics.newQuad(32, 0, 32, 32, w, h),
    }
  }
end

function searchbox:update(dt)
  if self.prevtext ~= self.data.text then
    self:resetTimers()
  end
  self.prevtext = self.data.text
end

function searchbox:draw()
  if self.state ~= 'inactive' then
    local _, _, w, h = self.icons.close.options.normal:getViewport()
    w = love.window.toPixels(w)
    h = love.window.toPixels(h)
    suit.Input(self.data, self.options, self.pos.x - w, self.pos.y, self.dims.x, self.dims.y)
    if suit.SpritesheetButton(self.icons.close.sheet,
                              self.icons.close.options,
                              winWidth - self.padding - w,
                              winHeight - self.padding - h,
                              0,
                              love.window.getPixelScale(),
                              love.window.getPixelScale()
                             ).hit then
      self:hide()
    end
  else
    local _, _, w, h = self.icons.search.options.normal:getViewport()
    w = love.window.toPixels(w)
    h = love.window.toPixels(h)
    if suit.SpritesheetButton(self.icons.search.sheet,
                              self.icons.search.options,
                              winWidth - self.padding - w,
                              winHeight - self.padding - h,
                              0,
                              love.window.getPixelScale(),
                              love.window.getPixelScale()
                             ).hit then
      self:show()
    end
  end
end

function searchbox:click(x, y)
  if x > self.pos.x and x < self.pos.x + self.dims.x and y > self.pos.y and y < self.pos.y + self.dims.y then
    self.state = 'focused'
    return true
  else
    self.state = 'inactive'
    return false
  end
end

function searchbox:show()
  self.state = 'opening'
  Timer.tween(0.5, self.dims, {x = self.maxDims.x}, 'out-cubic', function()
    self.state = 'active'
  end)
end

function searchbox:hide()
  self.state = 'closing'
  Timer.tween(0.5, self.dims, {x = 3}, 'out-cubic', function()
    self.data.text = ''
    self.state = 'inactive'
  end)
end

function searchbox:isActive()
  return true
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
  self.timer = Timer.after(1.0, function()
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

return searchbox
