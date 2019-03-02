---
-- Custom message box modal since SDL's message box is broken AF
---
local modal = {
  state = 'inactive',
  titleText = love.graphics.newText(headerFont, ''),
  cancelText = love.graphics.newText(font, 'Cancel'),
  cancelButtonIsHovered = false,
  confirmText = love.graphics.newText(font, 'OK'),
  confirmButtonIsHovered = false,
  w = 300,
  button_width_pad = 30,
  button_height_pad = 10,
}

local padding = 10

modal.name = 'Message Box Modal'

function modal:init()
  self:setTitle('Close PoE Planner?')
  self:setText("Click OK or press 'Enter' to confirm. Click Cancel or press 'Escape' to cancel and close this window.")
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
  local w, h = love.graphics.getDimensions()
  local x, y = (w-self.w)/2, (h-self.h)/2
  local padding = 5

  -- Draw inner and outer rect
  love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
  love.graphics.rectangle('fill', x, y, self.w, self.h)
  clearColor()
  love.graphics.rectangle('line', x, y, self.w, self.h)

  -- Draw Title bar
  y = y + padding
  love.graphics.draw(self.titleText, (w-self.titleText:getWidth())/2, y)

  -- Draw text
  y = y + self.titleText:getHeight() + padding
  love.graphics.draw(self.text, x+padding, y)

  -- Draw buttons
  y = (h+self.h)/2 - padding - self.button_height
  x = w/2
  love.graphics.rectangle('line', x-padding-self.button_width, y, self.button_width, self.button_height)
  if self.confirmButtonIsHovered then
    love.graphics.setColor(1, 0, 0, 0.4)
    love.graphics.rectangle('fill', x-padding-self.button_width, y, self.button_width, self.button_height)
    clearColor()
  end
  love.graphics.rectangle('line', x+padding, y, self.button_width, self.button_height)
  if self.cancelButtonIsHovered then
    love.graphics.setColor(1, 0, 0, 0.4)
    love.graphics.rectangle('fill', x+padding, y, self.button_width, self.button_height)
    clearColor()
  end

  -- Draw button text
  y = y + self.button_height_pad/2
  love.graphics.draw(self.confirmText, x-padding-self.button_width/2-self.confirmText:getWidth()/2, y)
  love.graphics.draw(self.cancelText, x+padding+(self.button_width/2-self.cancelText:getWidth()/2), y)

end

-- Check if user clicked on either button
function modal:click(mx, my)
  if not self:isActive() then return false end

  local padding = 10
  local w, h = love.graphics.getDimensions()
  local x, y = w/2, (h+self.h)/2 - padding - self.button_height

  -- Check left button (OK)
  if mx > x - padding/2 - self.button_width and
     mx < x - padding/2 and
     my > y and
     my < y + self.button_height then
    self.cb()
    return true
  end

  -- Check right button (Cancel)
  if mx > x + padding/2 and
     mx < x + padding/2 + self.button_width and
     my > y and
     my < y + self.button_height then
    self:setInactive()
    return true
  end

  return false
end

function modal:mousemoved(mx, my, dx, dy)
  if not self:isActive() then return false end

  local padding = 10
  local w, h = love.graphics.getDimensions()
  local x, y = w/2, (h+self.h)/2 - padding - self.button_height

  -- Check left button (OK)
  if mx > x - padding/2 - self.button_width and
    mx < x - padding/2 and
    my > y and
    my < y + self.button_height then
    self.confirmButtonIsHovered = true
    return true
  else
    self.confirmButtonIsHovered = false
  end

  -- Check right button (Cancel)
  if mx > x + padding/2 and
    mx < x + padding/2 + self.button_width and
    my > y and
    my < y + self.button_height then
    self.cancelButtonIsHovered = true
    return true
  else
    self.cancelButtonIsHovered = false
  end

  return false
end

function modal:setTitle(text)
  local width, wrappedtext = headerFont:getWrap(text, self.w - 2*padding)
  self.titleText:set(table.concat(wrappedtext, "\n"))
  self:updateHeights()
end

function modal:setText(text)
  local width, wrappedtext = font:getWrap(text, self.w - 2*padding)
  self.text = love.graphics.newText(font, table.concat(wrappedtext, "\n"))
  self:updateHeights()
end

function modal:updateHeights()
  if self.text == nil or self.titleText == nil then return end
  self.button_width = math.max(self.cancelText:getWidth(), self.confirmText:getWidth()) + self.button_width_pad
  self.button_height = math.max(self.cancelText:getHeight(), self.confirmText:getHeight()) + self.button_height_pad
  self.h = padding * 4 + self.button_height + self.text:getHeight() + self.titleText:getHeight()
end

return modal
