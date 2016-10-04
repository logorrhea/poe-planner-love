local toggle = {
  x = love.window.toPixels(10),
  y = love.window.toPixels(20),
  sx = 0.1*love.window.getPixelScale(),
  sy = 0.1*love.window.getPixelScale(),
  image = love.graphics.newImage('assets/menu.png'),
  name = 'Menu Toggle',
  status = 'active',
}

function toggle:init(target)
  self.target = target
end

function toggle:click(mx, my)
  local w, h = self.image:getDimensions()
  w, h = w*self.sx, h*self.sy
  local x1, y1 = self.x, self.y
  local x2, y2 = self.x + w, self.y + h
  if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
    self.target:toggle()
    return true
  else
    return false
  end
end

function toggle:draw()
  love.graphics.draw(self.image, self.x, self.y, 0, self.sx, self.sy)
end

function toggle:isActive()
  return self.status == 'active'
end

function toggle:isExclusive()
  return false
end

function toggle:toggle()
  if self.state == 'active' then
    self.state = 'inactive'
  else
    self.state = 'active'
  end
end

function toggle:activate()
  self.state = 'active'
end

function toggle:deactivate()
  self.state = 'inactive'
end


return toggle
