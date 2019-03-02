local lume = require 'lib.lume'

local camera = {
  x         = 0,
  y         = 0,
  scale     = 0.5,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05,
  pinchFix  = 2000,

  minX = -2500,
  maxX =  2500,

  minY = -2500,
  maxY =  2500,
}

function camera:zoomIn()
  self:setScale(self.scale + self.scaleStep)
  scaledHeight = winHeight/self.scale
  scaledWidth = winWidth/self.scale
  refillBatches()
end

function camera:zoomOut()
  self:setScale(self.scale - self.scaleStep)
  scaledHeight = winHeight/self.scale
  scaledWidth = winWidth/self.scale
  refillBatches()
end

function camera:pinch(dist)
  self:setScale(self.scale + dist/self.pinchFix)
  scaledHeight = winHeight/self.scale
  scaledWidth = winWidth/self.scale
  refillBatches()
end

function camera:setScale(scale)
  self.scale = lume.clamp(scale, self.minScale, self.maxScale)
end

function camera:setPosition(x, y)
  self.x = lume.clamp(x, self.minX, self.maxX)
  self.y = lume.clamp(y, self.minY, self.maxY)
end

function camera:worldToScreenCoords(x, y)
  local w,h,_ = love.window.getMode()
  x, y = x - self.x, y - self.y
  return x * self.scale + w/2, y * self.scale + h/2
end

return camera
