local strings = {}

function strings.capitalize(s)
  return string.upper(s:sub(1, 1))..s:sub(2, -1)
end

return strings
