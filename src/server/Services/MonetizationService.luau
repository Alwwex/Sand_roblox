--[[
	MonetizationService – gamepassy a developer produkty (nákupy za Robux).

	- Gamepassy: koupí se jednou, platí navždy. Ověřují se při připojení
	  a hned po nákupu (bez nutnosti se znovu připojit).
	- Developer produkty: dají se kupovat opakovaně (mince, Server Luck).
	  Zpracování přes ProcessReceipt s ochranou proti dvojímu připsání.

	ID se vyplňují v ReplicatedStorage > Shared > Config (GamePasses / Products).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local MonetizationService = {}

local MAX_STORED_RECEIPTS = 100

local function passKeyFromId(passId: number): string?
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

local function productKeyFromId(productId: number): string?
	for key, product in Config.Products do
		if product.Id ~= 0 and product.Id == productId then
			return key
		end
	end
	return nil
end

-- Aktivuje gamepass pro hráče
local function grantPass(player: Player, key: string, announce: boolean)
	local session = DataService.get(player)
	if not session or session.Passes[key] then
		return
	end
	session.Passes[key] = true
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		player:SetAttribute("VIP", true)
		-- Po koupi VIP dostane hráč Zlatou lopatu do ruky (pokud nemá lepší nástroj)
		local current = Config.ToolsById[session.Data.EquippedTool]
		local golden = Config.ToolsById.GoldenShovel
		if announce and golden and (not current or current.Index < golden.Index) then
			session.Data.EquippedTool = "GoldenShovel"
			ShopService.giveTool(player)
		end
	end
	DataService.markDirty(player)
	if announce then
		local pass = Config.GamePasses[key]
		DataService.notify(player, ("%s %s activated! Thank you! ❤️"):format(pass.Icon, pass.Name), "epic")
	end
end

-- Zkontroluje všechny gamepassy hráče (volá se po načtení dat)
function MonetizationService.loadPasses(player: Player)
	local giveAll = RunService:IsStudio() and Config.Testing.GiveAllPassesInStudio
	for key, pass in Config.GamePasses do
		if giveAll then
			grantPass(player, key, false)
		elseif pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				grantPass(player, key, false)
			end
		end
	end
end

---------------------------------------------------------------------
-- Developer produkty
---------------------------------------------------------------------

local PRODUCT_HANDLERS = {}

local function grantCoins(player: Player, session, baseCoins: number)
	local coins = baseCoins * (session.Data.Rebirths + 1)
	DataService.addCoins(player, coins)
	DataService.notify(player, ("💰 +%s coins! Thank you! ❤️"):format(Util.formatNumber(coins)), "epic")
end

PRODUCT_HANDLERS.CoinsSmall = function(player, session)
	grantCoins(player, session, Config.Products.CoinsSmall.Coins)
end
PRODUCT_HANDLERS.CoinsMedium = function(player, session)
	grantCoins(player, session, Config.Products.CoinsMedium.Coins)
end
PRODUCT_HANDLERS.CoinsLarge = function(player, session)
	grantCoins(player, session, Config.Products.CoinsLarge.Coins)
end
PRODUCT_HANDLERS.ServerLuck = function(player, _session)
	local now = os.time()
	local current = workspace:GetAttribute("ServerLuckUntil") or 0
	local base = math.max(now, current)
	workspace:SetAttribute("ServerLuckUntil", base + Config.Products.ServerLuck.LuckMinutes * 60)
	DataService.notifyAll(
		("🍀 %s activated SERVER LUCK! Rarer chests for everyone for %d minutes!"):format(
			player.DisplayName,
			Config.Products.ServerLuck.LuckMinutes
		),
		"epic"
	)
end

local function trimReceipts(receipts)
	local count = 0
	local oldestKey, oldestTime = nil, math.huge
	for key, time in receipts do
		count += 1
		if time < oldestTime then
			oldestKey, oldestTime = key, time
		end
	end
	if count > MAX_STORED_RECEIPTS and oldestKey then
		receipts[oldestKey] = nil
	end
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local session = DataService.get(player)
	if not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = session.Data
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if data.Receipts[purchaseId] then
		-- už jsme to připsali dřív
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = productKeyFromId(receiptInfo.ProductId)
	local handler = key and PRODUCT_HANDLERS[key]
	if not handler then
		warn("[Monetization] Neznámý produkt ID:", receiptInfo.ProductId, "– doplň ho do Config.Products")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(handler, player, session)
	if not ok then
		warn("[Monetization] Chyba při připsání produktu:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts[purchaseId] = os.time()
	trimReceipts(data.Receipts)
	DataService.markDirty(player)

	if not DataService.saveNow(player) then
		-- Data se nepodařilo uložit – Roblox zkusí nákup zpracovat znovu později.
		-- Účtenka je už zapsaná v paměti, takže se nákup v tomto serveru nepřipíše dvakrát.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local key = passKeyFromId(passId)
		if key then
			grantPass(player, key, true)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	-- Upozornění pro vývojáře
	local missing = {}
	for key, pass in Config.GamePasses do
		if pass.Id == 0 then
			table.insert(missing, key)
		end
	end
	if #missing > 0 then
		warn(
			"[Monetization] Gamepassy bez ID (nejdou koupit): "
				.. table.concat(missing, ", ")
				.. ". Vytvoř je na create.roblox.com a vlož ID do Config.GamePasses."
		)
	end
end

return MonetizationService
