--[[
	QuestService – denní úkoly. Každý den 3 náhodné úkoly podle pokroku hráče
	(začátečník / střední / pokročilý). Splněný úkol se vybírá v okně QUESTS.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

local function tierFor(data): number
	local tool = Config.ToolsById[data.EquippedTool]
	local index = if tool then tool.Index else 1
	if data.Rebirths >= 1 or index >= 6 then
		return 3
	elseif index >= 4 then
		return 2
	end
	return 1
end

-- Vygeneruje nové úkoly, když začal nový den
function QuestService.ensure(player: Player)
	local session = DataService.get(player)
	if not session then
		return nil
	end
	local data = session.Data
	local day = today()
	if type(data.Quests) ~= "table" or data.Quests.Day ~= day or type(data.Quests.List) ~= "table" then
		local rng = Random.new(math.abs(player.UserId) * 31 + day)
		local pool = {}
		for _, quest in Config.Quests do
			table.insert(pool, quest.Id)
		end
		local list = {}
		local tier = tierFor(data)
		for _ = 1, math.min(3, #pool) do
			local id = table.remove(pool, rng:NextInteger(1, #pool))
			local quest = Config.QuestsById[id]
			table.insert(list, { Id = id, Target = quest.Targets[tier], Progress = 0, Claimed = false, Tier = tier })
		end
		data.Quests = { Day = day, List = list }
		DataService.markDirty(player)
	end
	return data.Quests
end

function QuestService.progress(player: Player, questId: string, amount: number)
	local quests = QuestService.ensure(player)
	if not quests or amount <= 0 then
		return
	end
	for _, quest in quests.List do
		if quest.Id == questId and not quest.Claimed and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			if quest.Progress >= quest.Target then
				local info = Config.QuestsById[questId]
				DataService.notify(
					player,
					("%s Quest complete! Claim your reward in QUESTS 📋"):format(info.Icon),
					"success"
				)
			end
			DataService.markDirty(player)
		end
	end
end

function QuestService.claim(player: Player, index: number)
	local quests = QuestService.ensure(player)
	local session = DataService.get(player)
	local quest = quests and type(index) == "number" and quests.List[index]
	if not quest or not session then
		return false, "Unknown quest"
	end
	if quest.Claimed then
		return false, "Already claimed"
	end
	if quest.Progress < quest.Target then
		return false, "Not finished yet"
	end
	quest.Claimed = true
	local info = Config.QuestsById[quest.Id]
	local coins = info.Reward * (quest.Tier or 1) * (session.Data.Rebirths + 1)
	DataService.addCoins(player, coins)
	Remotes.Reward:FireClient(player, "Quest", coins)
	return true, ("Quest reward: +%s coins!"):format(Util.formatNumber(coins))
end

function QuestService.init()
	Remotes.ClaimQuest.OnServerInvoke = function(player, index)
		return QuestService.claim(player, index)
	end
	-- úkol "vydělej mince"
	DataService.onCoins(function(player, amount)
		QuestService.progress(player, "Coins", amount)
	end)
	-- nový den = nové úkoly (i pro hráče, kteří jsou zrovna ve hře)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				QuestService.ensure(player)
			end
		end
	end)
end

return QuestService
