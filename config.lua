local _M = {}

--[[
	Change script dir to your script directory
--]]
_M.ScriptDir = "/media/removable/Main/user1000/neat-donk"

_M.StateDir = _M.ScriptDir .. "/state/"
_M.PoolDir = _M.ScriptDir .. "/pool/"

--[[
	At the moment the first in list will get loaded.
	Rearrange for other savestates. (will be redone soon)
--]]
_M.State = {
	"PiratePanic.lsmv",
	"PiratePanicDitch.lsmv",
}

_M.Filename = _M.PoolDir .. _M.State[2]

--[[
	Start game with specific powerup.
	0 = No powerup
	1 = Mushroom
	2 = Feather
	3 = Flower
	Comment out to disable.
--]]
_M.StartPowerup = 0

_M.NeatConfig = {
--Filename = "DP1.state",
SaveFile = _M.Filename .. ".pool",
Filename = _M.Filename,
Population = 300,
DeltaDisjoint = 2.0,
DeltaWeights = 0.4,
DeltaThreshold = 1.0,
StaleSpecies = 15,
MutateConnectionsChance = 0.25,
PerturbChance = 0.90,
CrossoverChance = 0.75,
LinkMutationChance = 2.0,
NodeMutationChance = 0.50,
BiasMutationChance = 0.40,
StepSize = 0.1,
DisableMutationChance = 0.4,
EnableMutationChance = 0.2,
TimeoutConstant = 20,
MaxNodes = 1000000,
}

_M.ButtonNames = {
	"B",
	"Y",
	"Select",
	"Start",
	"Up",
	"Down",
	"Left",
	"Right",
	"A",
	"X",
	"L",
	"R"
}
	
_M.BoxRadius = 6
_M.InputSize = (_M.BoxRadius*2+1)*(_M.BoxRadius*2+1)

_M.Running = true

return _M
