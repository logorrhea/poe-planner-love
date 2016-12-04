local dialog = {
  x = 0,
  y = 0,
  status = 'inactive',
  width = love.window.toPixels(300),
  height = love.window.toPixels(300),
  maxWidth = 600,

  headerText = love.graphics.newText(headerFont, ''),
  contentText = love.graphics.newText(font, '')
  reminderText = love.graphics.newText(reminderFont, '')
  flavorText = love.graphics.newText(reminderFont, '')

  text = '',
}

function dialog:init()
  -- Determine max dialog width. The dialog box will
  -- be as wide as the text it contains, up to the max
  -- at which point it will wrap the contained text.
  local padding = love.window.toPixels(10)
  local w, h = love.graphics.getDimensions()
  if padding*2  + self.maxWidth > w then
    self.maxWidth = w - padding*2
  end
end

function dialog:isActive()
  return self.status = 'active'
end

function dialog:hide()
  self.status = 'inactive'
end

-- Sets dialog text to information about provided node
-- and sets dialog to visible
function dialog:show(node, x, y)
  if node == nil then return end

  local w, h = love.graphics.getDimensions()
  local width = self.maxWidth
  local text = ''
  local height = 0

  -- Header Text
  local lineWidth, lines = headerFont:getWrap(node.name)
  width = math.min(width, lineWidth)
  text = table.concat(lines, '\n')
  self.headerText:set(text)
  height = height + self.headerText:getHeight()

  -- Node Descriptions
  text = {}
  for i, desc in ipairs(node.descriptions) do
    lineWidth, lines = font:getWrap(desc)
    width = math.min(width, lineWidth)
    text[i] = table.concat(lines, '\n')
  end
  text = table.concat(text, '\n')
  self.contentText:set(text)
  height = height + self.contentText:getHeight()

  -- Reminder Text
  if node.reminderText then
    text = {}
    for i, reminder in ipairs(node.reminderText) do
      lineWidth, lines = reminderFont:getWrap(reminder)
      width = math.min(width, lineWidth)
      text[i] = table.concat(lines, '\n')
    end
    text = table.concat(text, '\n')
    self.reminderText:set(text)
  else
    self.reminderText:set('')
  end

  -- Flavour text
  if node.flavourText then
    text = {}
    for i, flavor in ipairs(node.flavourText) do
      lineWidth, lines = reminderFont:getWrap(flavor)
      width = math.min(width, lineWidth)
      text[i] = table.concat(lines, '\n')
    end
    text = table.concat(text, '\n')
    self.flavorText:set(text)
  else
    self.flavorText:set('')
  end

  -- Update window dimensions based on new text
  -- @TODO

  self.status = 'active'
end
