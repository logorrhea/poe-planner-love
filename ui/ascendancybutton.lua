local button = {
  state = 'inactive',
}

local images = {
  inactive = 'PassiveSkillScreenAscendancyButton',
  active   = 'PassiveSkillScreenAscendancyButtonHighlight',
  pressed  = 'PassiveSkillScreenAscendancyButtonPressed',
}

function button:init(data, nid)

  -- Overwrite initial values with actual images
  for state,name in pairs(images) do
    local key = lume.last(lume.sort(lume.keys(data.assets[name])))
    local fullPath = data.assets[name][key]

    local source = nil
    for match in fullPath:gmatch("[^/%.]+%.[^/%.]+") do
      source = match
    end

    images[state] = love.graphics.newImage('assets/'..source)
  end

  -- Set nid of start, calculation position
  self:changeStart(nid)
end

function button:changeStart(nid)
  self.nid = nid
  self.position = calculatePosition(nid)
end

function button:draw()
  local img = images[self.state]
  local w,h = img:getDimensions()
  love.graphics.draw(img, self.position.x-w/2, self.position.y-h/2)
end

function button:click(x, y)
  local w, h = images[self.state]:getDimensions()
  w,h = w*camera.scale/2, h*camera.scale/2
  local px, py = cameraCoords(self.position.x, self.position.y)
  local x1, x2 = px - w, px + w
  local y1, y2 = py - h, py + h

  local verdict = false
  if x > x1 and x < x2 and y > y1 and y < y2 then
    self:changeState()
    verdict = true
  end

  return verdict
end

function button:changeState()
  if self.state == 'inactive' then
    self.state = 'active'
  elseif self.state == 'active' then
    self.state = 'inactive'
  end
end

function button:isActive()
  return self.state == 'active'
end

function button:getPosition()
  return self.position.x, self.position.y
end

function calculatePosition(nid)
  local position = nodes[nid].position
  local radius = Node.Radii[Node.NT_START]
  local w, h = images[button.state]:getDimensions()
  local adj = {
    x = 0,
    y = radius,
  }
  return {
    x = position.x + adj.x,
    y = position.y + adj.y,
  }
end

return button
