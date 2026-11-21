--[[
	Stats – výpočty násobičů (mince, kapacita, rychlost, štěstí).
	Vše na jednom místě, ať se to snadno ladí.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Stats = {}

function Stats.artifactBonus(data): number
	local bonus = 0
	for artifactId, count in data.Artifacts do
		local artifact = Config.ArtifactsById[artifactId]
		if artifact and count > 0 then
			bonus += artifact.Bonus
		end
	end
	return bonus
end

function Stats.coinMultiplier(session): number
	local data = session.Data
	local multiplier = 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth
	multiplier *= 1 + Stats.artifactBonus(data)
	if session.Passes.DoubleCoins then
		multiplier *= Config.PassEffects.DoubleCoins
	end
	if session.Passes.VIP then
		multiplier *= Config.VIP.CoinBonus
	end
	if session.InGroup then
		multiplier *= 1 + Config.Group.CoinBonus
	end
	return multiplier
end

function Stats.capacity(session): number
	local backpack = Config.BackpacksById[session.Data.EquippedBackpack] or Config.Backpacks[1]
	local capacity = backpack.Capacity
	if session.Passes.BigBackpack then
		capacity *= Config.PassEffects.BigBackpack
	end
	return math.floor(capacity)
end

function Stats.digSpeed(session): number
	if session.Passes.FastDig then
		return Config.PassEffects.FastDig
	end
	return 1
end

function Stats.serverLuck(): number
	local luckUntil = workspace:GetAttribute("ServerLuckUntil") or 0
	if os.time() < luckUntil then
		return 2
	end
	return 1
end

function Stats.rebirthCost(data): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ data.Rebirths)
end

function Stats.ownsTool(session, toolId: string): boolean
	local tool = Config.ToolsById[toolId]
	if not tool then
		return false
	end
	if tool.Pass then
		return session.Passes[tool.Pass] == true
	end
	return session.Data.OwnedTools[toolId] == true
end

return Stats
