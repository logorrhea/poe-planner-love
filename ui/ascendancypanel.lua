local lume = require 'lib.lume'
local panel = {}
local images = {}
-- local scaleFix = 2.5
panel.name = 'Ascendancy Class Picker'


function panel:init(button, batches)
  self.button = button
  for _,class in ipairs(Node.Classes) do
    for _,aclass in ipairs(class.ascendancies) do
      local imageName = 'Classes'..string.upper(aclass:sub(1,1))..aclass:sub(2,-1)
      images[aclass] = batches[imageName]:getTexture()
    end
  end
end

-- Draw panel according to ascendancy button location
function panel:draw()
  local class = Node.Classes[activeClass].ascendancies[ascendancyClass]
  local img = images[class]
  if img then
    local x, y = self.button:getPosition()
    local w, h = img:getDimensions()

    love.graphics.draw(img, x-w/2, y)
  end
end

function panel:getCenter()
  local class = Node.Classes[activeClass].ascendancies[ascendancyClass]
  local img = images[class]
  if img then
    local x, y = self.button:getPosition()
    local w, h = img:getDimensions()
    return x, y+w/2
  end
end

function panel:containsMouse(x, y)
  local class = Node.Classes[activeClass].ascendancies[ascendancyClass]
  local w, h = images[class]:getDimensions()
  local r = (math.max(w, h)/2)*camera.scale
  local cx, cy = self:getCenter()
  cx, cy = camera:cameraCoords(cx, cy)
  local dx, dy = cx - x, cy - y
  return dx*dx + dy*dy <= r*r
end

--- Return ascendancy options for given or active class
function panel:getAscendancyBackground(aclass)
  return images[aclass]
end

return panel
