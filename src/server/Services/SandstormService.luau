--[[
	SandstormService – písečná bouře.
	Když hráči vykopou velkou část pouště (nebo uplyne čas), přijde bouře,
	všechny odnese do tábora a poušť se znovu zasype – s novými poklady
	a ruinami na jiném místě. Díky tomu hra "nikdy nedojde".

	Stav se posílá klientům přes atributy na Workspace:
	  DesertCleared (0..1), StormPhase ("Calm"/"Warning"/"Active"), StormIn (sekundy)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local TreasureService = require(script.Parent.TreasureService)
local WorldService = require(script.Parent.WorldService)

local S = Config.Sandstorm

local SandstormService = {}

local phase = "Calm"
local nextStorm = 0
local warningEnds = 0

local function setPhase(newPhase: string)
	phase = newPhase
	workspace:SetAttribute("StormPhase", newPhase)
end

local function runStorm()
	setPhase("Active")
	local started = os.clock()
	WorldService.setReady(false)

	-- Všechny odneseme do tábora, aby je písek nezasypal
	for _, player in Players:GetPlayers() do
		task.spawn(WorldService.teleportToCamp, player)
	end
	task.wait(1)

	TreasureService.clearAll()
	WorldService.regenerate()
	TreasureService.populate()

	local elapsed = os.clock() - started
	if elapsed < S.MinStormTime then
		task.wait(S.MinStormTime - elapsed)
	end

	WorldService.setReady(true)
	nextStorm = os.time() + S.Interval
	setPhase("Calm")
	DataService.notifyAll("🏜️ The storm is over! The desert is full of NEW treasures. Start digging!", "epic")
end

function SandstormService.forceStorm()
	if phase == "Calm" then
		nextStorm = os.time()
	end
end

function SandstormService.start()
	nextStorm = os.time() + S.Interval
	setPhase("Calm")

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			workspace:SetAttribute("DesertCleared", WorldService.getClearedFraction())

			if phase == "Calm" then
				workspace:SetAttribute("StormIn", math.max(0, nextStorm - now))
				if
					WorldService.isReady()
					and (WorldService.getClearedFraction() >= S.ClearedThreshold or now >= nextStorm)
				then
					warningEnds = now + S.WarningTime
					setPhase("Warning")
					DataService.notifyAll(
						("🌪️ A SANDSTORM is coming in %d seconds! The desert will be buried again!"):format(
							S.WarningTime
						),
						"storm"
					)
				end
			elseif phase == "Warning" then
				workspace:SetAttribute("StormIn", math.max(0, warningEnds - now))
				if now >= warningEnds then
					task.spawn(runStorm)
				end
			end
		end
	end)
end

return SandstormService
