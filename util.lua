local _M = {}

function _M.table_to_string(tbl)
    local result = "{"
    local keys = {}
    for k in pairs(tbl) do 
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = tbl[k]
        if type(v) == "number" and v == 0 then
            --goto continue
        end

        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result.._M.table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        elseif type(v) == "number" and v >= 0 then
            result = result..string.format("%x", v)
        else
            result = result.."\""..v.."\""
        end
        result = result..",\n"
        ::continue::
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end

function _M.file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

return _M
