--[[
	LeaderboardService – globální žebříčky (přes všechny servery).

	- Ukládá do OrderedDataStore: celkové mince, vykopaný písek, rebirthy.
	- Každých Config.Leaderboard.RefreshSeconds obnoví tabule v lobby
	  a pošle data do UI (ReplicatedStorage > LeaderboardData, JSON).
	- Nejbohatší hráč dostane sochu na zlatém podstavci v lobby.
	- Ve Studiu bez přístupu k API ukazuje aspoň hráče na serveru.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local LB = Config.Leaderboard

local BOARDS = {
	{
		Key = "Coins",
		Title = "RICHEST DIGGERS",
		Icon = "💰",
		Field = "TotalCoins",
		Color = Color3.fromRGB(255, 200, 50),
	},
	{
		Key = "Sand",
		Title = "MOST SAND DUG",
		Icon = "🏜️",
		Field = "TotalSand",
		Color = Color3.fromRGB(240, 170, 80),
	},
	{
		Key = "Rebirths",
		Title = "MOST REBIRTHS",
		Icon = "♻️",
		Field = "Rebirths",
		Color = Color3.fromRGB(80, 220, 255),
	},
}
local MEDALS = { "🥇", "🥈", "🥉" }

local LeaderboardService = {}

local stores = {}
local nameCache = {}
local boardRows = {} -- [key] = { {Rank, Name, Value} ... }
local dataValue: StringValue? = nil
local statueUserId: number? = -999 -- -999 = ještě nic nepostaveno
local statueModel: Model? = nil

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Player"
	nameCache[userId] = result
	return result
end

local function submit(player: Player, data)
	if player.UserId <= 0 then
		return
	end
	for _, board in BOARDS do
		local store = stores[board.Key]
		local value = math.floor(data[board.Field] or 0)
		if store and value > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

-- Načte top N ze serveru Robloxu; když to nejde, vezme hráče na serveru
local function fetch(board)
	local store = stores[board.Key]
	if store then
		local ok, entries = pcall(function()
			local pages = store:GetSortedAsync(false, LB.Size)
			return pages:GetCurrentPage()
		end)
		if ok and entries then
			local list = {}
			for _, entry in entries do
				local userId = tonumber(entry.key) or 0
				table.insert(list, { UserId = userId, Name = getName(userId), Value = entry.value })
			end
			if #list > 0 then
				return list
			end
		end
	end
	-- záloha: hráči na tomto serveru
	local list = {}
	for player, session in DataService.getAll() do
		table.insert(
			list,
			{ UserId = player.UserId, Name = player.DisplayName, Value = math.floor(session.Data[board.Field] or 0) }
		)
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	while #list > LB.Size do
		table.remove(list)
	end
	return list
end

---------------------------------------------------------------------
-- Tabule v lobby (SurfaceGui)
---------------------------------------------------------------------

local function buildBoardGui(part: BasePart, board)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(700, 900)
	surface.LightInfluence = 0
	surface.Parent = part

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 130)
	header.BackgroundColor3 = board.Color
	header.Parent = surface
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	gradient.Rotation = 90
	gradient.Parent = header
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 1, -20)
	title.Position = UDim2.fromOffset(15, 10)
	title.BackgroundTransparency = 1
	title.Text = board.Icon .. " " .. board.Title
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = header
	Build.stroke(title, 5)

	local rows = {}
	for i = 1, LB.Size do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(15, 140 + (i - 1) * 70)
		row.Size = UDim2.new(1, -30, 0, 62)
		row.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(70, 45, 25) else Color3.fromRGB(85, 55, 30)
		row.Parent = surface
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row
		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(0, 80, 1, 0)
		rank.BackgroundTransparency = 1
		rank.Text = MEDALS[i] or ("#" .. i)
		rank.Font = Enum.Font.LuckiestGuy
		rank.TextScaled = true
		rank.TextColor3 = Color3.fromRGB(255, 230, 170)
		rank.Parent = row
		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(90, 0)
		name.Size = UDim2.new(1, -300, 1, -10)
		name.BackgroundTransparency = 1
		name.Text = "---"
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = row
		local value = Instance.new("TextLabel")
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -15, 0, 0)
		value.Size = UDim2.new(0, 200, 1, -10)
		value.BackgroundTransparency = 1
		value.Text = ""
		value.Font = Enum.Font.LuckiestGuy
		value.TextScaled = true
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = board.Color
		value.Parent = row
		Build.stroke(value, 2)
		rows[i] = { Name = name, Value = value }
	end
	return rows
end

local function updateStatue(userId: number?)
	local lobby = WorldService.Lobby
	if not lobby or not lobby.StatueCFrame or userId == statueUserId then
		return
	end
	statueUserId = userId
	if statueModel then
		statueModel:Destroy()
		statueModel = nil
	end
	local model: Model? = nil
	if userId and userId > 0 then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if ok and result then
			model = result
		end
	end
	if model then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		local lift = 3
		if humanoid and root then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			lift = humanoid.HipHeight + root.Size.Y / 2
		end
		model:PivotTo(lobby.StatueCFrame * CFrame.new(0, lift, 0))
		model.Name = "TopPlayerStatue"
		model.Parent = lobby.StatueParent
		if root then
			Build.billboard(
				root,
				"👑 " .. getName(userId :: number),
				Color3.fromRGB(255, 220, 90),
				Vector2.new(10, 2),
				4.5,
				Enum.Font.FredokaOne
			)
		end
	else
		-- zástupná zlatá postavička
		model = Build.npc(lobby.StatueParent, lobby.StatueCFrame, {
			Skin = Color3.fromRGB(255, 200, 60),
			Shirt = Color3.fromRGB(255, 200, 60),
			Pants = Color3.fromRGB(255, 200, 60),
			Hat = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Metal,
		}, "👑 " .. (if userId then getName(userId) else "Be the #1!"))
	end
	statueModel = model
end

local function refresh()
	local payload = {}
	for _, board in BOARDS do
		local list = fetch(board)
		payload[board.Key] = list
		local rows = boardRows[board.Key]
		if rows then
			for i, row in rows do
				local entry = list[i]
				row.Name.Text = if entry then entry.Name else "---"
				row.Value.Text = if entry then Util.formatNumber(entry.Value) else ""
			end
		end
	end
	payload.Updated = os.time()
	if dataValue then
		dataValue.Value = HttpService:JSONEncode(payload)
	end
	local top = payload.Coins and payload.Coins[1]
	updateStatue(top and top.UserId or nil)
end

function LeaderboardService.init()
	for _, board in BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("LB_" .. board.Key .. "_" .. LB.Version)
		end)
		if ok then
			stores[board.Key] = store
		end
	end

	local value = Instance.new("StringValue")
	value.Name = "LeaderboardData"
	value.Value = "{}"
	value.Parent = ReplicatedStorage
	dataValue = value

	local lobby = WorldService.Lobby
	if lobby and lobby.Boards then
		for _, board in BOARDS do
			local part = lobby.Boards[board.Key]
			if part then
				boardRows[board.Key] = buildBoardGui(part, board)
			end
		end
	end

	DataService.onSaved(submit)

	task.spawn(function()
		task.wait(5)
		while true do
			pcall(refresh)
			task.wait(LB.RefreshSeconds)
		end
	end)
end

return LeaderboardService
