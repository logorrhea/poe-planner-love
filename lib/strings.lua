local strings = {}

function strings.capitalize(s)
  if s == nil then return '' end
  return string.upper(s:sub(1, 1))..s:sub(2, -1)
end

return strings
