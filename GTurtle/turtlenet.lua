local Object = require("GCC/Util/classics")
local GNet = require("GCC/GNet/gnet")

---@class GTurtle.TurtleNet
local TurtleNet = {}

---@class TurtleNet.TurtleHost.Options
---@field term table?

---@class TurtleNet.TurtleHost : GNet.Server
---@overload fun(options: TurtleNet.TurtleHost.Options) : TurtleNet.TurtleHost
TurtleNet.TurtleHost = GNet.Server:extend()

---@enum TurtleNet.TurtleHost.PROTOCOL
TurtleNet.TurtleHost.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE"
}

---@alias TurtleID number

---@param options TurtleNet.TurtleHost.Options
function TurtleNet.TurtleHost:new(options)
    options = options or {}
    ---@type GNet.Server.Options
    local serverOptions = {
        endpointConfigs = {
            [self.PROTOCOL.TURTLE_HOST_SEARCH] = self.OnTurtleHostSearch,
            [self.PROTOCOL.LOG] = self.OnLog,
            [self.PROTOCOL.REPLACE] = self.OnReplace
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    TurtleNet.TurtleHost.super.new(self, serverOptions)

    self.name = "TurtleHost_" .. self.id

    os.setComputerLabel(self.name)
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type TurtleID[]
    self.registeredTurtles = {}
end

---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnTurtleHostSearch(id, msg)
    term.native().write("Waiting for HostSearch...")
    table.insert(self.registeredTurtles, id)
    rednet.send(id, "Hello There!", TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
end
---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnLog(id, msg)
    print(string.format("[T%d]: %s", id, msg))
end
---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnReplace(id, msg)
    term.clear()
    term.setCursorPos(1, 1)
    print(msg)
end

---@class TurtleNet.TurtleHostClient.Options
---@field gTurtle GTurtle.Base

---@class TurtleNet.TurtleHostClient : Object
---@overload fun(options: TurtleNet.TurtleHostClient.Options) : TurtleNet.TurtleHostClient
TurtleNet.TurtleHostClient = Object:extend()

---@param options TurtleNet.TurtleHostClient
function TurtleNet.TurtleHostClient:new(options)
    self.gTurtle = options.gTurtle
    -- open all rednet modems attached to turtle
    peripheral.find("modem", rednet.open)
    self:SearchTurtleHost()
end

function TurtleNet.TurtleHostClient:SearchTurtleHost()
    rednet.broadcast("Searching For Turtle Host..", TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host (ID: %d)", self.hostID))
        self:SendLog("Hello There!")
    else
        self.gTurtle:Log("No Turtle Host Found")
    end
end

function TurtleNet.TurtleHostClient:SendLog(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleNet.TurtleHost.PROTOCOL.LOG)
end

function TurtleNet.TurtleHostClient:SendReplace(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleNet.TurtleHost.PROTOCOL.REPLACE)
end

return TurtleNet
