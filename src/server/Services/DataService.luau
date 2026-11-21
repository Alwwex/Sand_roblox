--[[
	DataService – ukládání hráčských dat (DataStore) + posílání dat klientovi.

	- Načítá data s jednoduchým "zámkem" (aby se data nepřepsala, když hráč
	  rychle přejde na jiný server).
	- Automaticky ukládá každou minutu, při odchodu hráče a při vypnutí serveru.
	- Ve Studiu bez zapnutého "Studio Access to API Services" hra funguje,
	  jen se nic neukládá (v Output uvidíš varování).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(script.Parent.Stats)

local STORE_NAME = "DuneDiggers_PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_TIMEOUT = 150 -- po kolika sekundách se "zámek" z jiného serveru považuje za mrtvý
local SYNC_INTERVAL = 0.1

local DataService = {}

local sessions = {} -- [Player] = session
local store = nil

local IS_STUDIO = RunService:IsStudio()

local function defaultData()
	return {
		Coins = Config.Economy.StartingCoins,
		Sand = 0,
		TotalSand = 0,
		Rebirths = 0,
		OwnedTools = { Hands = true },
		EquippedTool = "Hands",
		OwnedBackpacks = { Pocket = true },
		EquippedBackpack = "Pocket",
		Artifacts = {},
		Codes = {},
		Receipts = {},
		ChestsOpened = 0,
		FirstJoin = os.time(),
	}
end

-- Doplní chybějící klíče (když přidáš do hry nové věci, staré uložené hry je dostanou)
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
			else
				data[key] = value
			end
		end
	end
	return data
end

local function dataKey(player: Player): string
	return "Player_" .. player.UserId
end

local function getStore()
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
	return store
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local coins = leaderstats:FindFirstChild("Coins")
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if coins then
		coins.Value = math.min(data.Coins, 2 ^ 53)
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
end

-- Načte data s retry a zámkem. Vrací (ok, data, canSave)
local function loadFromStore(player: Player)
	local dataStore = getStore()
	if not dataStore then
		return false, nil
	end

	local key = dataKey(player)
	for attempt = 1, 8 do
		local lockedByOther = false
		local loaded = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function(old)
				if old and old.Lock and old.Lock.JobId ~= game.JobId and os.time() - old.Lock.Time < LOCK_TIMEOUT then
					lockedByOther = true
					return nil -- zrušit zápis
				end
				local data = old or defaultData()
				data.Lock = { JobId = game.JobId, Time = os.time() }
				loaded = data
				return data
			end)
		end)

		if ok and loaded then
			return true, loaded
		elseif ok and lockedByOther then
			warn(("[DataService] Data hráče %s jsou otevřená na jiném serveru, čekám..."):format(player.Name))
			if attempt >= 6 then
				-- Starý server se asi zasekl – převezmeme data
				local forced = nil
				local forceOk = pcall(function()
					dataStore:UpdateAsync(key, function(old)
						local data = old or defaultData()
						data.Lock = { JobId = game.JobId, Time = os.time() }
						forced = data
						return data
					end)
				end)
				if forceOk and forced then
					return true, forced
				end
			end
			task.wait(5)
		else
			warn("[DataService] Načtení dat selhalo:", err)
			if IS_STUDIO then
				-- Ve Studiu nečekáme – nejspíš není zapnutý přístup k API
				return false, nil
			end
			task.wait(2 * attempt)
		end

		if not player.Parent then
			return false, nil
		end
	end
	return false, nil
end

local function saveToStore(player: Player, session, releaseLock: boolean): boolean
	if not session.CanSave then
		return true
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end

	local data = session.Data
	if releaseLock then
		data.Lock = nil
	else
		data.Lock = { JobId = game.JobId, Time = os.time() }
	end

	local key = dataKey(player)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function(old)
				-- Pokud mezitím data převzal jiný server, nepřepisujeme je
				if old and old.Lock and old.Lock.JobId ~= game.JobId and os.time() - old.Lock.Time < LOCK_TIMEOUT then
					return nil
				end
				return data
			end)
		end)
		if ok then
			return true
		end
		warn("[DataService] Uložení selhalo:", err)
		task.wait(attempt)
	end
	return false
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

function DataService.get(player: Player)
	return sessions[player]
end

-- Počká, dokud se hráči nenačtou data (max timeout sekund)
function DataService.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not sessions[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return sessions[player]
end

function DataService.markDirty(player: Player)
	local session = sessions[player]
	if session then
		session.Dirty = true
	end
end

function DataService.buildPayload(session)
	local data = session.Data
	return {
		Coins = data.Coins,
		Sand = data.Sand,
		TotalSand = data.TotalSand,
		Capacity = Stats.capacity(session),
		Rebirths = data.Rebirths,
		RebirthCost = Stats.rebirthCost(data),
		CoinMultiplier = Stats.coinMultiplier(session),
		DigSpeed = Stats.digSpeed(session),
		OwnedTools = data.OwnedTools,
		EquippedTool = data.EquippedTool,
		OwnedBackpacks = data.OwnedBackpacks,
		EquippedBackpack = data.EquippedBackpack,
		Artifacts = data.Artifacts,
		ArtifactBonus = Stats.artifactBonus(data),
		Passes = session.Passes,
		InGroup = session.InGroup,
		ChestsOpened = data.ChestsOpened,
	}
end

function DataService.syncNow(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Dirty = false
	updateLeaderstats(player, session.Data)
	Remotes.DataSync:FireClient(player, DataService.buildPayload(session))
end

-- Okamžité uložení (používá se po nákupu za Robux)
function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	return saveToStore(player, session, false)
end

function DataService.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function DataService.notifyAll(text: string, kind: string?)
	Remotes.Notify:FireAllClients(text, kind or "info")
end

-- Načte hráče. Vrací session nebo nil (když se data nepodařilo načíst)
function DataService.loadPlayer(player: Player)
	local ok, data = loadFromStore(player)
	local canSave = ok

	if not ok then
		if IS_STUDIO then
			warn(
				"[DataService] Data se ve Studiu NEUKLÁDAJÍ. Zapni: Game Settings > Security > "
					.. "Enable Studio Access to API Services (hra musí být publikovaná)."
			)
			data = defaultData()
		else
			if player.Parent then
				player:Kick("Could not load your data. Please rejoin in a moment!")
			end
			return nil
		end
	end

	if not player.Parent then
		-- hráč mezitím odešel – uvolníme zámek
		if canSave then
			saveToStore(player, { Data = data, CanSave = true }, true)
		end
		return nil
	end

	reconcile(data, defaultData())

	if IS_STUDIO and Config.Testing.StudioStartCoins > 0 and data.Coins < Config.Testing.StudioStartCoins then
		data.Coins = Config.Testing.StudioStartCoins
	end

	local session = {
		Data = data,
		Passes = {},
		InGroup = false,
		CanSave = canSave,
		Dirty = true,
		LastDig = 0,
		LastSellTouch = 0,
		LastCampTeleport = 0,
		LastFullNotice = 0,
	}

	if Config.Group.Id and Config.Group.Id > 0 then
		local groupOk, inGroup = pcall(function()
			return player:IsInGroup(Config.Group.Id)
		end)
		session.InGroup = groupOk and inGroup == true
	end

	createLeaderstats(player)
	sessions[player] = session
	return session
end

function DataService.releasePlayer(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	saveToStore(player, session, true)
	sessions[player] = nil
end

function DataService.init()
	getStore()

	-- Synchronizace dat ke klientům (max 10x za sekundu)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < SYNC_INTERVAL then
			return
		end
		accumulator = 0
		for player, session in sessions do
			if session.Dirty then
				DataService.syncNow(player)
			end
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				task.spawn(saveToStore, player, session, false)
			end
		end
	end)

	Remotes.GetData.OnServerInvoke = function(player)
		local session = sessions[player]
		if not session then
			return nil
		end
		return DataService.buildPayload(session)
	end

	-- Uložení všech při vypnutí serveru
	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			pending += 1
			task.spawn(function()
				saveToStore(player, session, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.releasePlayer(player)
	end)
end

return DataService
