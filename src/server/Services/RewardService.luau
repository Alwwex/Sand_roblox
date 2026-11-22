--[[
	RewardService – denní odměna, VIP salonek a gamepass stánky v lobby.

	- DAILY REWARD truhla (lobby + tlačítko v UI) – jednou za Config.Daily.CooldownHours
	- VIP REWARD truhla ve VIP salonku – jen pro majitele VIP
	- Do VIP salonku smí jen VIP (ostatní to vrátí ke vchodu a nabídne VIP)
	- Gamepass stánky: přijdeš k zářící kouli a koupíš pass
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local RewardService = {}

local lastVipKick = {} -- [Player] = os.clock()

local function cooldownLeft(lastTime: number): number
	return math.max(0, lastTime + Config.Daily.CooldownHours * 3600 - os.time())
end

local function formatLong(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	return string.format("%dh %02dm", h, m)
end

function RewardService.claimDaily(player: Player)
	local session = DataService.get(player)
	if not session then
		return false, "Not ready yet"
	end
	local data = session.Data
	local left = cooldownLeft(data.LastDaily)
	if left > 0 then
		return false, "Next daily reward in " .. formatLong(left)
	end
	local coins = Config.Daily.Coins * (data.Rebirths + 1)
	data.LastDaily = os.time()
	DataService.addCoins(player, coins)
	Remotes.Reward:FireClient(player, "Daily", coins)
	return true, ("Daily reward: +%s coins!"):format(Util.formatNumber(coins))
end

function RewardService.claimVip(player: Player)
	local session = DataService.get(player)
	if not session then
		return false, "Not ready yet"
	end
	if not session.Passes.VIP then
		local pass = Config.GamePasses.VIP
		if pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end
		return false, "This chest is for VIPs only 👑"
	end
	local data = session.Data
	local left = cooldownLeft(data.LastVipChest)
	if left > 0 then
		return false, "Next VIP reward in " .. formatLong(left)
	end
	local coins = Config.Daily.VipCoins * (data.Rebirths + 1)
	data.LastVipChest = os.time()
	DataService.addCoins(player, coins)
	Remotes.Reward:FireClient(player, "Vip", coins)
	return true, ("VIP reward: +%s coins! 👑"):format(Util.formatNumber(coins))
end

local function addPrompt(part: BasePart?, actionText: string, objectText: string, hold: number, callback)
	if not part then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(callback)
	return prompt
end

local function insideBox(position: Vector3, zone): boolean
	return position.X >= zone.Min.X
		and position.X <= zone.Max.X
		and position.Y >= zone.Min.Y
		and position.Y <= zone.Max.Y
		and position.Z >= zone.Min.Z
		and position.Z <= zone.Max.Z
end

function RewardService.init()
	local lobby = WorldService.Lobby or {}

	Remotes.ClaimDaily.OnServerInvoke = function(player)
		return RewardService.claimDaily(player)
	end

	addPrompt(lobby.DailyChest, "Claim", "Daily Reward", 0.5, function(player)
		local ok, message = RewardService.claimDaily(player)
		DataService.notify(player, message, if ok then "success" else "info")
	end)
	addPrompt(lobby.VipChest, "Claim", "VIP Reward", 0.5, function(player)
		local ok, message = RewardService.claimVip(player)
		DataService.notify(player, message, if ok then "epic" else "info")
	end)

	-- Gamepass stánky
	for key, orb in lobby.PassStands or {} do
		local pass = Config.GamePasses[key]
		addPrompt(orb, "Buy", pass.Name, 0, function(player)
			local session = DataService.get(player)
			if session and session.Passes[key] then
				DataService.notify(player, "You already own " .. pass.Name .. " ✅", "success")
			elseif pass.Id == 0 then
				DataService.notify(player, "This gamepass is not set up yet", "error")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
		-- skutečná cena z Robloxu
		if pass.Id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(pass.Id, Enum.InfoType.GamePass)
				end)
				local label = orb:FindFirstChild("Price", true)
				if ok and info and info.PriceInRobux and label and label:IsA("TextLabel") then
					label.Text = "R$ " .. info.PriceInRobux
				end
			end)
		end
	end

	-- VIP salonek – kdo nemá VIP, toho to vrátí ke vchodu
	local zone = lobby.VipZone
	if zone then
		task.spawn(function()
			while true do
				task.wait(0.4)
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local session = DataService.get(player)
					if root and session and not session.Passes.VIP and insideBox(root.Position, zone) then
						character:PivotTo(zone.Exit)
						local now = os.clock()
						if now - (lastVipKick[player] or 0) > 12 then
							lastVipKick[player] = now
							DataService.notify(
								player,
								"👑 VIP LOUNGE is for VIPs only! Get VIP in the STORE.",
								"epic"
							)
							local pass = Config.GamePasses.VIP
							if pass.Id ~= 0 then
								MarketplaceService:PromptGamePassPurchase(player, pass.Id)
							end
						end
					end
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastVipKick[player] = nil
	end)
end

return RewardService
