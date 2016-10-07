local touchy = {
  _version = '0.1.0',
  key = 'lctrl',
}

local kb = love.keyboard
local g = love.graphics
local mouse = love.mouse

local p1 = {
  lastX = nil,
  lastY = nil,
  dx = nil,
  dy = nil,
  x = nil,
  y = nil,
}
local p2 = {
  lastX = nil,
  lastY = nil,
  dx = nil,
  dy = nil,
  x = nil,
  y = nil,
}

local dragSpacing = 60

function touchy.getTouches()
  if kb.isScancodeDown(touchy.key) and (mouse.isDown(1) or mouse.isDown(2)) then
    return {[1]=p1,[2]=p2}
  end
  return {}
end

function touchy.update(dt)
  if kb.isScancodeDown(touchy.key) then
    local x, y = mouse.getPosition()
    local button = mouse.isDown(2) and 2 or 1
    calculatePoints(x, y, button)

    -- Send touchmoved signals
    if mouse.isDown(1) or mouse.isDown(2) then
      love.touchmoved(1, p1.x, p1.y, p1.dx, p1.dy, 1)
      love.touchmoved(2, p2.x, p2.y, p2.dx, p2.dy, 1)
    end
  else
    -- de-init points
    nillifyTouches()
  end
end

function touchy.mousepressed(x, y, button, isTouch)
  if isTouch or not kb.isScancodeDown(touchy.key) then
    return false
  else
    calculatePoints(x, y, button)
    love.touchpressed(1, p1.x, p1.y, 0, 0, 1)
    -- love.touchpressed(1, p2.x, p2.y, 0, 0, 1)
    return true
  end
end

function touchy.mousereleased(x, y, button, isTouch)
  if isTouch or not kb.isScancodeDown(touchy.key) then
    return false
  else
    calculatePoints(x, y, button)
    love.touchreleased(1, p1.x, p1.y, 0, 0, 1)
    -- love.touchreleased(2, p2.x, p2.y, 0, 0, 1)
    return true
  end
end

function touchy.draw()
  if kb.isScancodeDown(touchy.key) then
    if mouse.isDown(1) or mouse.isDown(2) then
      g.setColor(255, 0, 255, 100)
    else
      g.setColor(255, 255, 255, 100)
    end
    g.circle('fill', p1.x, p1.y, 20)
    g.circle('fill', p2.x, p2.y, 20)
  end
end

function calculatePoints(x, y, button)
  local w, h, _ = love.window.getMode()
  -- Two-finger drag motion
  if button == 2 then
    p1.y, p2.y = y, y
    p1.x, p2.x = x - dragSpacing, x + dragSpacing

    -- Pinch/rotation motions
  else
    p1.x, p1.y = x, y
    p2.x = w/2 + (w/2 - x)
    p2.y = h/2 + (h/2 - y)
  end

  -- If this is the first pass, set lastX and lastY to x and y
  -- so that dx/dy are 0
  if p1.lastX == nil or p2.lastX == nil then
    p1.lastX = p1.x
    p2.lastX = p2.x
    p1.lastY = p1.y
    p2.lastY = p2.y
  end

  -- Calculate dx and dy
  p1.dx = p1.x - p1.lastX
  p1.dy = p1.y - p1.lastY
  p2.dx = p2.x - p2.lastX
  p2.dy = p2.y - p2.lastY

  -- Set new lastX/lastY
  p1.lastX = p1.x
  p1.lastY = p1.y
  p2.lastX = p2.x
  p2.lastY = p2.y
end

function nillifyTouches()
  p1.x = nil
  p2.x = nil
  p1.y = nil
  p2.y = nil
  p1.dx = nil
  p2.dx = nil
  p1.dy = nil
  p2.dy = nil
  p1.lastX = nil
  p2.lastX = nil
  p1.lastY = nil
  p2.lastY = nil
end

return touchy
