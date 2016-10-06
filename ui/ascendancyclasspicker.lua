local picker = {}
local imageWidth, imageHeight

function picker:init()
  self.state = 'inactive'
  self:setOptions()
  self:setCenters()
end

function picker:setOptions(class)
  self.options = {}
  self.class = class or activeClass
  for i, aclass in ipairs(Node.Classes[self.class].ascendancies) do
    self.options[#self.options+1] = ascendancyPanel:getAscendancyBackground(aclass)
  end
end

function picker:setCenters()
  self.centers = {}
  local theta = math.pi/6
  imageWidth, imageHeight = self.options[1]:getDimensions()
  local limit = math.min(winWidth, winHeight)
  self.r = limit/5
  local w = 2*self.r
  self.scale = math.min(w/imageWidth, 1.0)

  local xadj = self.r + self.r/6
  local yadj = math.tan(theta) * xadj

  local center = vec(winWidth/2, winHeight/2)
  self.centers[1] = center + vec(-xadj, -yadj)
  self.centers[2] = center + vec(xadj, -yadj)
  local hyp  = lume.distance(center.x, center.y, self.centers[1].x, self.centers[1].y)
  self.centers[3] = center + vec(0, hyp)
end

function picker:draw()
  for i, c in ipairs(self.centers) do
    if self.options[i] then
      love.graphics.draw(self.options[i], c.x, c.y, 0, self.scale, self.scale, imageWidth/2, imageHeight/2)
    end
  end
end

function picker:click(x, y)
  local choice = nil
  for i, c in ipairs(self.centers) do
    local dx, dy = c.x - x, c.y - y
    if dx * dx + dy * dy <= self.r * self.r then
      choice = i
      changeActiveClass(self.class, choice)
    end
  end

  self:toggle()
  return choice
end

function picker:isActive()
  return self.state == 'active'
end

function picker:isExclusive()
  return true
end

function picker:toggle()
  if self.state == 'active' then
    self.state = 'inactive'
  else
    self.state = 'active'
  end
end

function picker:activate()
  self.state = 'active'
end


return picker
