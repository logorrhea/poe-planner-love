local t

function t.test()
  local c = love.thread.getChannel('gsc')
  local nodes = c:pop()
  print(#nodes)
  c:push('done')
end

return t
