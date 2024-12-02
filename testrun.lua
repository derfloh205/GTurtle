local GTurtle = require("GCC/GTurtle/gturtle")

local RT =
    GTurtle.Rubber {
    name = "Rubby",
    minimumFuel = 100,
    log = true,
    clearLog = true,
    visualizeGridOnMove = true
}

RT:Refuel()
RT:ExecuteMovement("FRFLFFLFFRFLFFRFFR")

local path = RT.nav:CalculatePathToStart()

if path then
    for i, node in ipairs(path) do
        RT:Log(string.format("%d#: (%s)", i, tostring(node.pos)))
    end
else
    RT:Log("No Path Found")
end
