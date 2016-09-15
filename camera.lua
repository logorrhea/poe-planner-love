local lume = require 'vendor.lume.lume'

local camera = {
  x         = 0,
  y         = 0,
  scale     = 0.5,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05,
  pinchFix  = 100,
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

return camera
