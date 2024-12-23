---@class GCC.Util.GPull
local GPull = {}

---@class GHAPI.CommitData
---@field author table
---@field comitter table
---@field message string
---@field tree GHAPI.TreeBaseData
---@field url string
---@field comment_count number
---@field verification table

---@class GHAPI.CommitAPIData
---@field sha string
---@field node_id string
---@field commit GHAPI.CommitData
--- and more

---@class GHAPI.TreeBaseData
---@field sha string
---@field url string

---@class GHAPI.TreeDataListElement : GHAPI.TreeBaseData
---@field path string
---@field mode string
---@field type "blob"|"tree"

---@class GHAPI.TreeAPIData : GHAPI.TreeBaseData
---@field tree GHAPI.TreeDataListElement[]
---@field truncated boolean

---@class GPull.Config
---@field shaMap table<string, string> ID -> SHA

GPull.CONFIG_FILE = ".gpull"

local args = {...}

if #args < 2 then
    print("Usage: gpull <user> <repo> (<access-token>)")
    return
end

local user = args[1]
local repo = args[2]
local token = args[3]

local headers = {
    ["Accept"] = "application/vnd.github+json",
    ["Authorization"] = string.format("Bearer %s", token),
    ["X-GitHub-Api-Version"] = "2022-11-28"
}

---@type table<string, boolean>
GPull.commitPaths = {}
---@type table<string, boolean>
GPull.cachedPaths = {}

function GPull:SplitPath(pathString)
    local elements = {}
    for p in pathString:gmatch("([^/]*)") do
        table.insert(elements, p)
    end
    return elements
end

function GPull:GetParentPaths(pathString)
    local splitPath = self:SplitPath(pathString)
    local parentPaths = {}
    local cPath = ""
    for _, part in ipairs(splitPath) do
        cPath = fs.combine(cPath, part)
        table.insert(parentPaths, cPath)
    end
    return parentPaths
end

function GPull:GetConfig()
    if not fs.exists(GPull.CONFIG_FILE) then
        local file = fs.open(GPull.CONFIG_FILE, "w")
        file.write("{}")
        file.close()
    end
    local configFile = fs.open(GPull.CONFIG_FILE, "r")
    local config = textutils.unserialiseJSON(configFile.readAll()) or {}
    configFile.close()
    config.shaMap = config.shaMap or {}
    return config
end

function GPull:WriteConfig(config)
    local configFile = fs.open(GPull.CONFIG_FILE, "w")
    configFile.write(textutils.serialiseJSON(config or {}))
    configFile.close()
end

function GPull:UpdateSha(sha, id)
    local config = self:GetConfig()
    config.shaMap[id] = sha
    self:WriteConfig(config)
end

---@param sha string
---@param id string | "COMMIT"
function GPull:IsShaCached(sha, id)
    self.commitPaths[id] = true
    local config = self:GetConfig()
    local cached = sha == config.shaMap[id]
    if cached then
        self.cachedPaths[id] = true
    end
    return cached
end

function GPull:Get(url)
    if token then
        return http.get(url, headers)
    else
        return http.get(url)
    end
end

---@param commitSha string
---@param path string full path
---@param subTreeData GHAPI.TreeDataListElement
function GPull:UpdateBlob(commitSha, path, subTreeData)
    local fileName = subTreeData.path
    local basePath = fs.combine(repo, path)
    local filePath = fs.combine(basePath, fileName)
    if self:IsShaCached(subTreeData.sha, filePath) then
        print("No Changes: " .. fileName)
        return
    else
        self:UpdateSha(subTreeData.sha, filePath)
    end

    print("Pulling Changes: " .. fileName .. " ..")
    local fileUrl =
        string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/%s", user, repo, commitSha, path, fileName)
    local response = self:Get(fileUrl)
    if response then
        fs.makeDir(basePath)
        local fileContent = response.readAll()
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileUrl)
    end
end

---@param commitSha string
---@param path string
---@param treeBaseData GHAPI.TreeBaseData
function GPull:UpdateTree(commitSha, path, treeBaseData)
    local url = treeBaseData.url
    local treeResponse = self:Get(url)
    ---@type GHAPI.TreeAPIData
    local treeAPIData = textutils.unserialiseJSON(treeResponse.readAll())
    -- base path is always not cached cause a commit needs changes
    if path ~= "" then
        local treePath = fs.combine(repo, path)
        if self:IsShaCached(treeBaseData.sha, treePath) then
            return
        else
            self:UpdateSha(treeBaseData.sha, treePath)
        end
    end

    for _, subTreeData in ipairs(treeAPIData.tree) do
        if subTreeData.type == "tree" then
            self:UpdateTree(commitSha, fs.combine(path, subTreeData.path), subTreeData)
        elseif subTreeData.type == "blob" then
            self:UpdateBlob(commitSha, path, subTreeData)
        end
    end
end

function GPull:RemoveDeletedFiles()
    local config = self:GetConfig()
    for path, _ in pairs(config.shaMap) do
        if not self.commitPaths[path] and path ~= "COMMIT" then
            -- check if myself or parent path was cached
            local parentPaths = GPull:GetParentPaths(path)
            local pathCached = false
            for _, parentPath in ipairs(parentPaths) do
                if self.cachedPaths[parentPath] then
                    pathCached = true
                    break
                end
            end
            if not pathCached then
                print("Delete: " .. path)
                config.shaMap[path] = nil
                if fs.exists(path) then
                    fs.delete(path)
                end
            end
        end
    end
    self:WriteConfig(config)
end

function GPull:PullRepository()
    print(string.format("Pulling from github.com/%s/%s", user, repo))
    local commitApiUrl = string.format("https://api.github.com/repos/%s/%s/commits", user, repo)
    local commitResponse = self:Get(commitApiUrl)
    ---@type GHAPI.CommitAPIData[]
    local commitResponseData = textutils.unserialiseJSON(commitResponse.readAll())
    local commitSha = commitResponseData[1].sha
    if self:IsShaCached(commitSha, "COMMIT") then
        print("Up to Date.")
        return
    else
        self:UpdateSha(commitSha, "COMMIT")
    end
    self:UpdateTree(commitSha, "", commitResponseData[1].commit.tree)
    self:RemoveDeletedFiles()
end

GPull:PullRepository()
