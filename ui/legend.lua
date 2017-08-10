local legend = {
	name = 'Keyboard Shortcut Legend',
	padding = love.window.toPixels(50)
}

local headerText = love.graphics.newText(headerFont, 'Keyboard Shortcuts')

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

	-- Inner rectangle

	-- Main Header
	local win_w, win_h = love.graphics.getDimensions()
	local w, h = headerText:getDimensions()

	love.graphics.draw(headerText, win_w/2, self.padding*2, 0, 1, 1, w/2, h/2)
end

return legend
