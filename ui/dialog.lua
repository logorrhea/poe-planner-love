local dialog = {
  x = 0,
  y = 0,
  status = 'inactive',
  width = 600,
  height = 300,
  -- width = love.window.toPixels(600),
  -- height = love.window.toPixels(300),
  maxWidth = 500,

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
  -- local padding = love.window.toPixels(10)
  local padding = 10
  local w, h = love.graphics.getDimensions()
  if (padding*2 + self.maxWidth) > w then
    self.maxWidth = w - padding*2
  end
  self.width = self.maxWidth
  -- print(self.maxWidth)
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

  -- local padding = love.window.toPixels(10)
  local padding = 10
  local w, h = love.graphics.getDimensions()
  local width = 0
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

  -- Add padding and store width/height
  self.width = width + 2*padding
  self.height = height + 2*padding


  -- Calculate position if none provided (would just always calculate,
  -- but calcs are different for ascendancy nodes)
  if x == nil or y == nil then
    x, y = camera:cameraCoords(node.position.x, node.position.y)
  end
  self.position.x = x
  self.position.y = y

  -- Adjust position based on node position and screen size
  self:adjustPosition()

  self.status = 'active'
end

function dialog:adjustPosition()
  -- local offset = love.window.toPixels(20)
  local offset = 20
  local x, y = self.position.x, self.position.y
  local w, h = love.graphics.getDimensions()

  if x < w/2 and y < h/2 then     -- Upper-left
    x, y = x + offset, y + offset
  elseif x > w/2 and y < h/2 then -- Upper-right
    x, y = x - self.width - offset, y + offset
  elseif x < w/2 and y > h/2 then -- Lower-left
    x, y = x + offset, y - self.height - offset
  else                            -- Lower-right
    x, y = x - self.width - offset, y - self.height - offset
  end

  if (x + self.width) > w or x < 0 then
    x = w/2 - self.width/2
  end

  self.position.x = x
  self.position.y = y
end

function dialog:draw()
  -- local five = love.window.toPixels(5)
  local five = 5
  local ten = 2*five

  -- Draw innner and outer rectangle
  love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
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
