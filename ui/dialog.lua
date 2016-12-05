local dialog = {
  x = 0,
  y = 0,
  status = 'inactive',
  width = love.window.toPixels(600),
  height = love.window.toPixels(300),
  maxWidth = 600,

  headerText = love.graphics.newText(headerFont, ''),
  contentText = love.graphics.newText(font, ''),
  reminderText = love.graphics.newText(reminderFont, ''),
  flavorText = love.graphics.newText(reminderFont, ''),

  text = '',
  position = vec(0, 0)
}

function dialog:init()
  -- Determine max dialog width. The dialog box will
  -- be as wide as the text it contains, up to the max
  -- at which point it will wrap the contained text.
  local padding = love.window.toPixels(10)
  local w, h = love.graphics.getDimensions()
  if (padding*2 + self.maxWidth) > w then
    self.maxWidth = w - padding*2
  end
  print(self.maxWidth)
end

function dialog:isActive()
  return self.status == 'active'
end

function dialog:hide()
  self.status = 'inactive'
end

-- Sets dialog text to information about provided node
-- and sets dialog to visible
function dialog:show(node, x, y)
  if node == nil then return end

  local padding = love.window.toPixels(10)
  local w, h = love.graphics.getDimensions()
  local width = self.maxWidth
  local text = ''
  local height = 0

  -- Header Text
  local lineWidth, lines = headerFont:getWrap(node.name, self.maxWidth)
  width = math.max(width, lineWidth)
  text = table.concat(lines, '\n')
  self.headerText:set(text)
  height = height + self.headerText:getHeight() + padding

  -- Node Descriptions
  text = {}
  for i, desc in ipairs(node.descriptions) do
    lineWidth, lines = font:getWrap(desc, self.maxWidth)
    width = math.max(width, lineWidth)
    text[i] = table.concat(lines, '\n')
  end
  text = table.concat(text, '\n')
  self.contentText:set(text)
  height = height + self.contentText:getHeight()

  -- Reminder Text
  if node.reminderText then
    height = height + padding
    text = {}
    for i, reminder in ipairs(node.reminderText) do
      lineWidth, lines = reminderFont:getWrap(reminder, self.maxWidth)
      width = math.max(width, lineWidth)
      text[i] = table.concat(lines, '\n')
    end
    text = table.concat(text, '\n')
    self.reminderText:set(text)
    height = height + self.reminderText:getHeight()
  else
    self.reminderText:set('')
  end

  -- Flavour text
  if node.flavourText then
    height = height + padding
    text = {}
    for i, flavor in ipairs(node.flavourText) do
      lineWidth, lines = reminderFont:getWrap(flavor, self.maxWidth)
      width = math.max(width, lineWidth)
      text[i] = table.concat(lines, '\n')
    end
    text = table.concat(text, '\n')
    self.flavorText:set(text)
    height = height + self.flavorText:getHeight()
  else
    self.flavorText:set('')
  end

  -- Update window dimensions based on new text
  -- @TODO
  self.width = width + 2*padding
  self.height = height + 2*padding

  -- Calculate position based on node position and screen size
  x, y = camera:cameraCoords(node.position.x, node.position.y)
  -- x, y = adjustDialogPosition(x, y, dialogPosition.w, dialogPosition.h, five*4)
  self.position.x = x
  self.position.y = y

  self.status = 'active'
end

function dialog:draw()
  local five = love.window.toPixels(5)
  local ten = 2*five

  -- Draw innner and outer rectangle
  love.graphics.setColor(1, 1, 1, 250)
  love.graphics.rectangle('fill', self.position.x, self.position.y, self.width, self.height)
  clearColor()
  love.graphics.rectangle('line', self.position.x, self.position.y, self.width, self.height)

  -- Draw text
  local x = self.position.x + ten
  local y = self.position.y + ten

  love.graphics.draw(self.headerText, x, y)
  y = y + self.headerText:getHeight() + ten

  love.graphics.draw(self.contentText, x, y)
  y = y + self.contentText:getHeight()

  if self.reminderText:getHeight() > 0 then
    y = y + ten
    love.graphics.setColor(mutedTextColor)
    love.graphics.draw(self.reminderText, x, y)
    y = y + self.reminderText:getHeight()
  end

  if self.flavorText:getHeight() > 0 then
    y = y + ten
    love.graphics.setColor(flavorTextColor)
    love.graphics.draw(self.flavorText, x, y)
    y = y + self.flavorText:getHeight()
  end

  clearColor()
end


return dialog
