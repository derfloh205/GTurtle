--- Table Utils
---@class GCC.Util.TUtil
local TUtil = {}

---@param table table
---@param element any
function TUtil:tContains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

--- Inject tableB into tableA
---@param tableA table
---@param tableB table
function TUtil:Inject(tableA, tableB)
    for k, v in pairs(tableB) do
        tableA[k] = v
    end
end

---@param tableA table list
---@param tableB table list
---@return table
function TUtil:Concat(tableA, tableB)
    local concatTable = {}

    for _, i in ipairs(tableA) do
        table.insert(concatTable, i)
    end
    for _, i in ipairs(tableB) do
        table.insert(concatTable, i)
    end

    return concatTable
end

---@generic T
---@generic K
---@param t table<K, T> | T[]
---@param findFunc fun(element: T, key: K):boolean
---@return T | nil
---@return K | nil
function TUtil:Find(t, findFunc)
    for k, v in pairs(t) do
        if findFunc(v, k) then
            return v, k
        end
    end
    return nil
end

---@generic T
---@generic K
---@param t table<K, T> | T[]
---@param filterFunc fun(element: T, key: K): boolean
---@param preserveKeys? boolean
---@return table<K, T>
function TUtil:Filter(t, filterFunc, preserveKeys)
    local filtered = {}
    for k, v in pairs(t) do
        if filterFunc(v, k) then
            if preserveKeys then
                filtered[k] = v
            else
                table.insert(filtered, v)
            end
        end
    end
    return filtered
end

---@generic T
---@generic K
---@generic R
---@param t table<K, T> | T[]
---@param mapFunc fun(element: T, key: K): R
---@param preserveKeys? boolean
---@return R[] | table<K, R>
function TUtil:Map(t, mapFunc, preserveKeys)
    local mapped = {}
    for k, v in pairs(t) do
        if preserveKeys then
            mapped[k] = mapFunc(v, k)
        else
            local value = mapFunc(v, k)
            if value then
                table.insert(mapped, value)
            end
        end
    end
    return mapped
end

---@generic T
---@generic K
---@param t table<K, T> | T[]
---@param conFunc fun(element: T, key: K) : boolean
---@return boolean allTrue
function TUtil:Every(t, conFunc)
    for k, v in pairs(t) do
        if not conFunc(v, k) then
            return false
        end
    end
    return true
end

---@generic T
---@generic K
---@param t table<K, T> | T[]
---@param conFunc fun(element: T, key: K) : boolean
---@return boolean oneTrue
function TUtil:Some(t, conFunc)
    for k, v in pairs(t) do
        if conFunc(v, k) then
            return true
        end
    end
    return false
end

---@generic T
---@generic K
---@param t T[]
---@param element T
function TUtil:RemoveFromList(t, element)
    local index =
        self:Find(
        t,
        function(v)
            return v == element
        end
    )
    table.remove(t, index)
end

return TUtil
