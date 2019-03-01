local portrait = {
  x = love.window.toPixels(5),
  y = love.window.toPixels(5),
}


function portrait:init(image, parent, target)
  self.parent = parent
  self.target = target
  self:updatePortrait(image)
end

function portrait:updatePortrait(image)
  self.image = image
  local w, h = self.image:getDimensions()
  self.w = w*love.window.getDPIScale()
  self.h = h*love.window.getDPIScale()
end

function portrait:draw()
  love.graphics.draw(self.image, self.parent.x + self.x, self.parent.y+self.y, 0, love.window.getDPIScale(), love.window.getDPIScale())
end

function portrait:isActive()
  return self.parent:isActive()
end

function portrait:isExclusive()
  return false
end

function portrait:click(mx, my)
  local x2, y2 = self.x+self.w, self.y+self.h
  if mx >= self.x and mx <= x2 and my >= self.y and my <= y2 then
    self.parent:toggle()
    self.target:toggle()
    return true
  else
    return false
  end
end


return portrait
