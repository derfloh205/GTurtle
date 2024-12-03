local GLogAble = require("GCC/Util/glog")
local f = string.format

---@class GNet
local GNet = {}

---@class GNet.Server.EndpointConfig
---@field protocol? string
---@field callback fun(server: GNet.Server, id: number, msg: string)

---@class GNet.Server.Options : GLogAble.Options
---@field endpointConfigs GNet.Server.EndpointConfig[]

---@class GNet.Server : GLogAble
---@overload fun(options: GNet.Server.Options) : GNet.Server
GNet.Server = GLogAble:extend()

---@param options GNet.Server.Options
function GNet.Server:new(options)
    options = options or {}

    ---@diagnostic disable-next-line: redundant-parameter
    GNet.Server.super.new(self, options)
    self.id = os.getComputerID()

    ---@type GNet.Server.EndpointConfig[]
    self.endpoints = options.endpointConfigs or {}

    peripheral.find("modem", rednet.open)
end

function GNet.Server:Run()
    local endpointCallbacks = {}

    for _, endpoint in ipairs(self.endpoints) do
        table.insert(
            endpointCallbacks,
            function()
                self:Log(f("Listening for: [%s]", endpoint))
                while true do
                    local id, msg = rednet.receive(endpoint.protocol)
                    endpoint.callback(self, id, msg)
                end
            end
        )
    end

    -- debug
    local funcs = {
        function()
            sleep(1)
            print("hello1")
        end,
        function()
            sleep(2)
            print("hello2")
        end,
        function()
            sleep(3)
            print("hello3")
        end
    }
    parallel.waitForAll(table.unpack(funcs))

    --parallel.waitForAll(table.unpack(endpointCallbacks))
end

return GNet
