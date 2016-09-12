local camera = {
  x         = 0,
  y         = 0,
  scale     = 0.5,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05,
}

function camera:zoomIn()
  self.scale = self.scale + self.scaleStep
  self.scale = lume.clamp(self.scale, self.minScale, self.maxScale)
  scaledHeight = winHeight/self.scale
  scaledWidth = winWidth/self.scale
  refillBatches()
end

function camera:zoomOut()
  self.scale = self.scale - self.scaleStep
  self.scale = lume.clamp(self.scale, self.minScale, self.maxScale)
  scaledHeight = winHeight/self.scale
  scaledWidth = winWidth/self.scale
  refillBatches()
end

return camera
