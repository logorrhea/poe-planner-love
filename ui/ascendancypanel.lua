local lume = require 'vendor.lume.lume'
local panel = {}
local images = {}


function panel:init(button, batches)
  self.button = button
  for _,class in ipairs(Node.AscendancyClasses) do
    local imageName = 'Classes'..string.upper(class:sub(1,1))..class:sub(2,-1)
    images[class] = batches[imageName]:getTexture()
    print(class, imageName, images[class]:getDimensions())
  end
end

-- Draw panel according to ascendancy button location
function panel:draw()
  local img = images['ascendant']
  local x, y = self.button:getPosition()
  local w, h = img:getDimensions()

  love.graphics.draw(img, x-w/2, y)
end

function panel:getCenter()
  local x, y = self.button:getPosition()
  local w, h = images['ascendant']:getDimensions()
  return x, y+w/2
end

return panel
