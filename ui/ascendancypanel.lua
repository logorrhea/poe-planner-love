local lume = require 'vendor.lume.lume'
local panel = {}
local images = {}


function panel:init(batches)
  for _,class in ipairs(Node.AscendancyClasses) do
    local imageName = 'Classes'..string.upper(class:sub(1,1))..class:sub(2,-1)
    images[class] = batches[imageName]:getTexture()
    print(class, imageName, images[class]:getDimensions())
  end
end

-- Draw panel according to ascendancy button location
function panel:draw(button)
  local img = images['ascendant']
  local x, y = button:getPosition()
  local w, h = img:getDimensions()

  love.graphics.draw(img, x-w/2, y)
end

return panel
