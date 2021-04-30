local classes = _SYSTEM.all_classes()
io.stderr:write(classes:gsub(classes:sub(8,1), '\n'))
for k,v in pairs(_SYSTEM) do
    print(k)
end