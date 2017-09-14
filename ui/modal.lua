---
-- Custom message box modal since SDL's message box is broken AF
---
local modal = {
  state = 'inactive',
  bodyText = "Click OK or press 'Enter' to confirm. Click Cancel or press 'Escape' to cancel and close this window.",
  -- text = love.graphics.newText(font, "Click OK or press 'Enter' to confirm. Click Cancel or press 'Escape' to cancel and close this window."),
  titleText = love.graphics.newText(headerFont, 'Close PoE Planner?'),
  cancelText = love.graphics.newText(font, 'Cancel'),
  confirmText = love.graphics.newText(font, 'OK'),

  w = 300,

  button_width_pad = love.window.toPixels(10)*3,
  button_height_pad = love.window.toPixels(10),
}
modal.name = 'Message Box Modal'

function modal:init()
  local five = love.window.toPixels(5)
  local ten = 2*five

  local width, wrappedtext = font:getWrap(self.bodyText, self.w - 2*ten)
  self.text = love.graphics.newText(font, table.concat(wrappedtext, "\n"))

  self.button_width = math.max(self.cancelText:getWidth(), self.confirmText:getWidth()) + self.button_width_pad
  self.button_height = math.max(self.cancelText:getHeight(), self.confirmText:getHeight()) + self.button_height_pad

  self.h = ten * 4 + self.button_height + self.text:getHeight() + self.titleText:getHeight()
end

function modal:isExclusive()
  return true
end

function modal:toggle(confirmationCallback)
  if self:isActive() then
    self:setActive(confirmationCallback)
  else
    self:setInactive()
  end
end

function modal:setConfirmAction(confirmationCallback)
  self.cb = function()
    confirmationCallback()
    self:setInactive()
  end
end

function modal:isActive()
  return self.state == 'active'
end

function modal:setActive(confirmationCallback)
  self.state = 'active'
  if confirmationCallback ~= nil then
    self:setConfirmAction(confirmationCallback)
  end
end

function modal:setInactive()
  self.state = 'inactive'
end

function modal:confirm()
  self.cb()
end

function modal:draw()
  local five = love.window.toPixels(5)
  local ten = 2*five

  local w, h = love.graphics.getDimensions()
  local x, y = (w-self.w)/2, (h-self.h)/2

  -- Draw inner and outer rect
  love.graphics.setColor(1, 1, 1, 250)
  love.graphics.rectangle('fill', x, y, self.w, self.h)
  clearColor()
  love.graphics.rectangle('line', x, y, self.w, self.h)

  -- Draw Title bar
  y = y + ten
  love.graphics.draw(self.titleText, (w-self.titleText:getWidth())/2, y)

  -- Draw text
  y = y + self.titleText:getHeight() + ten
  love.graphics.draw(self.text, x+ten, y)

  -- Draw buttons
  y = (h+self.h)/2 - ten - self.button_height
  x = w/2
  love.graphics.rectangle('line', x-five-self.button_width, y, self.button_width, self.button_height)
  love.graphics.rectangle('line', x+five, y, self.button_width, self.button_height)
  
  -- Draw button text
  y = y + self.button_height_pad/2
  love.graphics.draw(self.confirmText, x-five-self.button_width/2-self.confirmText:getWidth()/2, y)
  love.graphics.draw(self.cancelText, x+five+(self.button_width/2-self.cancelText:getWidth()/2), y)

end

-- Check if user clicked on either button
function modal:click(mx, my)
  if not self:isActive() then return false end

  local ten = love.window.toPixels(10)
  local w, h = love.graphics.getDimensions()
  local x, y = w/2, (h+self.h)/2 - ten - self.button_height

  -- Check left button (OK)
  if mx > x - ten/2 - self.button_width and
     mx < x - ten/2 and
     my > y and
     my < y + self.button_height then
    self.cb()
    return true
  end

  -- Check right button (Cancel)
  if mx > x + ten/2 and
     mx < x + ten/2 + self.button_width and
     my > y and
     my < y + self.button_height then
    self:setInactive()
    return true
  end

  return false
end


return modal