local legend = {
	name = 'Keyboard Shortcut Legend',
	padding = love.window.toPixels(50),
	column_padding = love.window.toPixels(200),
	shortcuts = {
		{
			key = 'F1',
			description = 'Toggle debug panel',
		},
		{
			key = '`',
			description = 'Toggle stat panel',
		},
		{
			key = 'Escape',
			description = 'Close active UI element or exit application',
		},
		{
			key = '?',
			description = 'Display this help screen',
		},
		{
			key = '[ and ]',
			description = 'Toggle between stat list and build list when stat panel is open',
		},
    {
      key = 'Ctrl+f',
      description = 'Toggle search'
    },
    {
      key = '/',
      description = 'Enable search'
    }
	}
}

local headerText = love.graphics.newText(headerFont, 'Keyboard Shortcuts')
local keyText = love.graphics.newText(headerFont, 'XXXXXXXXXXXXXXXXXXXX')
local descriptionText = love.graphics.newText(font, 'Description')

function legend:init()
	self:resize()
end

function legend:resize()
	local width, height = love.graphics.getDimensions()
	self.outer_rect = {
		x = self.padding,
		y = self.padding,
		w = width - self.padding*2,
		h = height - self.padding*2,
		color = {20, 20, 20, 240}
	}
end

function legend:draw()
	-- Outer Rectangle
	love.graphics.setColor(self.outer_rect.color)
	love.graphics.rectangle('fill', self.outer_rect.x, self.outer_rect.y, self.outer_rect.w, self.outer_rect.h)
	love.graphics.setColor(255, 255, 255, 255)

	-- Main Header
	local win_w, win_h = love.graphics.getDimensions()
	local w, h = headerText:getDimensions()
	local y = self.padding*2

	love.graphics.draw(headerText, win_w/2, y, 0, 1, 1, w/2, h/2)
	y = y + h + self.padding

	local x1 = self.padding * 2
	local x2 = x1 + self.column_padding
	local x3 = win_w - self.padding * 2
	for i, shortcut in ipairs(self.shortcuts) do
		keyText:set(shortcut.key)
		descriptionText:set(shortcut.description)
		love.graphics.draw(keyText, x1, y)
		love.graphics.draw(descriptionText, x2, y)
		y = y + h
		love.graphics.line(x1, y, x3, y)
		y = y + h
	end

end

return legend
