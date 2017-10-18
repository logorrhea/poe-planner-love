local strings = {}

function strings.capitalize(s)
  if s == nil return ''
  return string.upper(s:sub(1, 1))..s:sub(2, -1)
end

return strings
