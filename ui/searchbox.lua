local searchbox = {
  name = 'Search Box',
  data = {text = ''},
  text = '',
  prevtext = '',
  padding = 10,
  dims = vec(100, 20),
  state = 'inactive',
  matches = {
    regular = {},
    ascendancy = {},
  }
}

function searchbox:init()
  self.pos = vec(winWidth - self.padding - self.dims.x, winHeight - self.padding - self.dims.y)
  self:blinkTimer()
end

function searchbox:update(dt)
  if self.prevtext ~= self.data.text then
    self:resetTimers()
  end
  self.prevtext = self.data.text
end

function searchbox:draw()
  suit.Input(self.data, self.pos.x, self.pos.y, self.dims.x, self.dims.y)
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
