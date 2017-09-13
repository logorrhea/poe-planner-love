local picker = {}
picker.name = 'Class Picker'


function picker:init(target)
  self.state = 'inactive'
  self.target = target
  self:setOptions()
  self:setCenters()
end

function picker:draw()
  local imageWidth, imageHeight = self.options[1]:getDimensions()
  for i, c in ipairs(self.centers) do
    if self.options[i] then
      love.graphics.draw(self.options[i], c.x, c.y, 0, self.scale, self.scale, imageWidth/2, imageHeight/2)
    end
  end
end

function picker:setOptions()
  self.options = {}
  for i, class in ipairs(Node.Classes) do
    self.options[#self.options+1] = love.graphics.newImage('assets/'..class.name..'-portrait.png')
  end
end

function picker:setCenters()
  self.centers = {}

  local theta = math.pi/6
  local limit = winWidth
  local imageWidth, imageHeight = self.options[1]:getDimensions()
  local minR = imageWidth*1.15
  local maxR = 2*minR

  local limit = math.min(winWidth, winHeight)
  local r = lume.clamp((limit-imageWidth)/2, minR, maxR)

  local center = vec(winWidth/2, winHeight/2)
  local x = r*math.cos(theta)
  local y = r*math.sin(theta)

  self.centers[1] = center
  self.centers[2] = center + vec(-x, y)
  self.centers[3] = center + vec(x, y)
  self.centers[4] = center + vec(0, -r)
  self.centers[5] = center + vec(0, r)
  self.centers[6] = center + vec(-x, -y)
  self.centers[7] = center + vec(x, -y)
end

function picker:getPortrait(class)
  return self.options[class]
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

function picker:deactivate()
  self.state = 'inactive'
end

function picker:click(x, y)
  local w, h = self.options[1]:getDimensions()
  local choice = nil

  for i, c in ipairs(self.centers) do
    local minx, miny = c.x - w/2, c.y - h/2
    local maxx, maxy = c.x + w/2, c.y + h/2
    if x < maxx and x > minx and y < maxy and y > miny then
      -- only one option for scion
      if i == 1 then
        changeActiveClass(1, 1)
      else
        self.target:setOptions(i)
        self.target:toggle()
        choice = i
      end
    end
  end

  self:toggle()
  if choice == nil then
    startingNewBuild = false
  end
  return choice
end


return picker
