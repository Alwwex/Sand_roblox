--[[
	Hud – herní rozhraní na obrazovce:
	mince (animované počítadlo), bonusy, menu vlevo, rychlá tlačítka vpravo,
	banner s postupem pouště a bouří, batoh dole, notifikace a efekty.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Hotbar = require(script.Parent.Hotbar)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local new = UIKit.new

local Hud = {}

local root: Frame
local fxLayer: Frame
local refs = {}
local dots = {}
local ctx = nil
local state = nil
local coinValue: NumberValue
local lastCoins: number? = nil
local toastCounter = 0

local KIND_COLORS = {
	info = T.Dark,
	success = T.Green,
	error = T.Red,
	full = T.Red,
	epic = T.Purple,
	storm = T.Orange,
}

local function formatMultiplier(value: number): string
	local text = string.format("%.2f", value)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

---------------------------------------------------------------------
-- Stavba
---------------------------------------------------------------------

local function buildCurrency()
	local panel = new("Frame", {
		Name = "Currency",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(300, 130),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local pill = new("Frame", {
		Name = "CoinsPill",
		Size = UDim2.fromOffset(300, 62),
		BackgroundColor3 = Color3.fromRGB(110, 66, 30),
		BackgroundTransparency = 0.05,
		Parent = panel,
	})
	UIKit.corner(pill, 31)
	UIKit.stroke(pill, 3, T.Gold)
	UIKit.shade(pill, 0.45)
	refs.CoinIcon = UIKit.coin(pill, 50, UDim2.fromOffset(6, 6), 3)
	refs.Coins = UIKit.text({
		Text = "0",
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.new(1, -120, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UIKit.Font.Title,
		TextColor3 = T.Gold,
		Stroke = 2.5,
		ZIndex = 3,
		Parent = pill,
	})
	refs.CoinsScale = new("UIScale", { Parent = pill })
	-- zelené "+" otevře obchod za Robux
	UIKit.button({
		Size = UDim2.fromOffset(44, 48),
		Position = UDim2.new(1, -50, 0, 7),
		Color = T.Green,
		Text = "+",
		Radius = 22,
		Depth = 4,
		Parent = pill,
		OnClick = function()
			ctx.open("Store")
		end,
	})

	local chips = new("Frame", {
		Position = UDim2.fromOffset(4, 68),
		Size = UDim2.fromOffset(300, 30),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = chips })
	local function chip(name: string, color: Color3, width: number)
		local frame =
			new("Frame", { Name = name, Size = UDim2.fromOffset(width, 32), BackgroundColor3 = color, Parent = chips })
		UIKit.corner(frame, 16)
		UIKit.stroke(frame, 2.5)
		UIKit.shade(frame, 0.15)
		local label = UIKit.text({
			Text = "",
			Position = UDim2.fromOffset(8, 3),
			Size = UDim2.new(1, -16, 1, -6),
			Font = UIKit.Font.Title,
			Parent = frame,
		})
		return frame, label
	end
	refs.MultiChip, refs.Multiplier = chip("Multiplier", T.Orange, 178)
	refs.RebirthChip, refs.Rebirths = chip("Rebirths", T.Cyan, 74)
	refs.LuckChip, refs.Luck = chip("Luck", T.Green, 220)
	-- Server Luck má vlastní řádek pod čipy (nepřekrývá banner pouště)
	refs.LuckChip.Parent = panel
	refs.LuckChip.Position = UDim2.fromOffset(4, 104)
	refs.LuckChip.Visible = false
end

local function buildMenu()
	local menu = new("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(14, 150),
		Size = UDim2.fromOffset(2 * 76 + 10, 5 * 80 + 4 * 10),
		BackgroundTransparency = 1,
		Parent = root,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(76, 80),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local items = {
		{ "Shop", "🛒", "SHOP", T.Orange },
		{ "Pets", "🐾", "PETS", Color3.fromRGB(255, 110, 160) },
		{ "Store", "💎", "STORE", T.Purple },
		{ "Quests", "📋", "QUESTS", T.Green },
		{ "Rebirth", "♻️", "REBIRTH", T.Cyan },
		{ "Daily", "🎁", "DAILY", Color3.fromRGB(70, 190, 120) },
		{ "Index", "📜", "INDEX", Color3.fromRGB(196, 130, 66) },
		{ "Codes", "🎟️", "CODES", T.Pink },
		{ "Top", "🏆", "TOP", T.Gold },
		{ "Camp", "⛺", "CAMP", T.Blue },
	}
	for index, item in items do
		local _, _, dot = UIKit.menuButton({
			Name = item[1],
			Icon = item[2],
			Label = item[3],
			Color = item[4],
			LayoutOrder = index,
			Parent = menu,
			OnClick = function()
				ctx.menu(item[1])
			end,
		})
		dots[item[1]] = dot
	end

	local right = new("Frame", {
		Name = "QuickMenu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 20),
		Size = UDim2.fromOffset(76, 2 * 80 + 10),
		BackgroundTransparency = 1,
		Parent = root,
	})
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	local _, musicFace = UIKit.menuButton({
		Name = "Music",
		Icon = "🎵",
		Label = "MUSIC",
		Color = Color3.fromRGB(90, 120, 230),
		LayoutOrder = 1,
		Parent = right,
		OnClick = function()
			ctx.menu("Music")
		end,
	})
	refs.MusicFace = musicFace
	UIKit.menuButton({
		Name = "Settings",
		Icon = "⚙️",
		Label = "SETTINGS",
		Color = T.Gray,
		LayoutOrder = 2,
		Parent = right,
		OnClick = function()
			ctx.menu("Settings")
		end,
	})
end

local function buildBanner()
	local banner = new("Frame", {
		Name = "Desert",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(440, 90),
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	UIKit.corner(banner, 18)
	UIKit.stroke(banner, 3)
	refs.DesertTitle = UIKit.text({
		Text = "DESERT CLEARED: 0%",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Font = UIKit.Font.Title,
		Parent = banner,
	})
	local _, fill = UIKit.bar({
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 20),
		Color = T.Orange,
		Radius = 10,
		Parent = banner,
	})
	refs.DesertFill = fill
	refs.Storm = UIKit.text({
		Text = "",
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 0, 24),
		Font = UIKit.Font.Body,
		Parent = banner,
	})
	refs.Banner = banner
end

local function buildSandBar()
	local panel = new("Frame", {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(520, 84),
		BackgroundTransparency = 1,
		Parent = root,
	})
	refs.Tool = UIKit.text({ Text = "", Size = UDim2.new(1, 0, 0, 26), Font = UIKit.Font.Body, Parent = panel })
	local _, fill, label = UIKit.bar({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 50),
		Color = T.Sand,
		Radius = 16,
		Parent = panel,
	})
	refs.SandFill = fill
	refs.SandLabel = label
	refs.Hint = UIKit.text({
		Text = "👆 HOLD click / tap to dig!  Sell sand at the golden SELL pad 💰",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(700, 32),
		TextColor3 = T.Gold,
		Font = UIKit.Font.Title,
		Stroke = 3,
		Visible = false,
		Parent = panel,
	})
	refs.HintScale = new("UIScale", { Parent = refs.Hint })
end

---------------------------------------------------------------------
-- Notifikace a efekty
---------------------------------------------------------------------

function Hud.toast(message: string, kind: string?)
	local k = kind or "info"
	local color = KIND_COLORS.info
	if string.sub(k, 1, 7) == "rarity:" then
		local rarity = Config.Rarities[string.sub(k, 8)]
		color = if rarity then rarity.Color else T.Gold
	elseif KIND_COLORS[k] then
		color = KIND_COLORS[k]
	end
	toastCounter += 1
	local toast = new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = color, LayoutOrder = toastCounter, Parent = refs.Toasts }
	)
	UIKit.corner(toast, 14)
	UIKit.stroke(toast, 3)
	UIKit.shade(toast, 0.2)
	UIKit.text({
		Text = message,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Stroke = 2,
		Parent = toast,
	})
	local scale = UIKit.pop(toast, 0.5)
	local toasts = {}
	for _, child in refs.Toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #toasts - 4 do
			toasts[i]:Destroy()
		end
	end
	task.delay(4, function()
		if toast.Parent then
			local tween = TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 })
			tween:Play()
			tween.Completed:Wait()
			toast:Destroy()
		end
	end)
end

function Hud.bigPopup(message: string, color: Color3)
	local label = UIKit.text({
		Text = message,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(640, 90),
		TextColor3 = color,
		Font = UIKit.Font.Title,
		Stroke = 5,
		ZIndex = 40,
		Parent = fxLayer,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	UIKit.pop(label, 0.3)
	task.delay(0.9, function()
		local info = TweenInfo.new(0.6)
		TweenService:Create(label, info, { Position = UDim2.fromScale(0.5, 0.32), TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
		task.wait(0.65)
		label:Destroy()
	end)
end

function Hud.flash(color: Color3?, strength: number?)
	local frame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or T.White,
		BackgroundTransparency = 1 - (strength or 0.45),
		ZIndex = 50,
		Parent = fxLayer,
	})
	TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.55, function()
		frame:Destroy()
	end)
end

-- Mince letí ze středu obrazovky do počítadla
function Hud.flyCoins(count: number)
	local icon = refs.CoinIcon
	local iconPos, iconSize = icon.AbsolutePosition, icon.AbsoluteSize
	local layerPos, layerSize = fxLayer.AbsolutePosition, fxLayer.AbsoluteSize
	if not (iconPos and iconSize and layerPos and layerSize) or layerSize.X < 1 then
		return
	end
	local rel = iconPos + iconSize / 2 - layerPos
	local target = UDim2.fromScale(rel.X / layerSize.X, rel.Y / layerSize.Y)
	for i = 1, math.clamp(count, 3, 12) do
		local coin = UIKit.coin(fxLayer, 40, UDim2.new(0.5, math.random(-120, 120), 0.5, math.random(-60, 60)), 45)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		task.delay(i * 0.04, function()
			local tween =
				TweenService:Create(coin, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = target,
					Size = UDim2.fromOffset(26, 26),
				})
			tween:Play()
			tween.Completed:Wait()
			coin:Destroy()
		end)
	end
end

---------------------------------------------------------------------
-- Aktualizace
---------------------------------------------------------------------

function Hud.updateWorld()
	local cleared = workspace:GetAttribute("DesertCleared") or 0
	local phase = workspace:GetAttribute("StormPhase") or "Calm"
	local stormIn = workspace:GetAttribute("StormIn") or 0
	refs.DesertTitle.Text = "DESERT CLEARED: " .. Util.formatPercent(cleared)
	refs.DesertFill.Size = UDim2.fromScale(math.clamp(cleared / Config.Sandstorm.ClearedThreshold, 0, 1), 1)
	if phase == "Warning" then
		refs.Storm.Text = ("⚠️ SANDSTORM IN %ds!"):format(stormIn)
		refs.Storm.TextColor3 = Color3.fromRGB(255, 120, 90)
		refs.Banner.BackgroundColor3 = Color3.fromRGB(120, 30, 20)
	elseif phase == "Active" then
		refs.Storm.Text = "🌪️ SANDSTORM! Burying the desert..."
		refs.Storm.TextColor3 = Color3.fromRGB(255, 170, 80)
		refs.Banner.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
	else
		refs.Storm.Text = ("🌪️ Sandstorm in %s or at %d%% cleared"):format(
			Util.formatTime(stormIn),
			math.floor(Config.Sandstorm.ClearedThreshold * 100)
		)
		refs.Storm.TextColor3 = T.White
		refs.Banner.BackgroundColor3 = T.Dark
	end
	local luckLeft = (workspace:GetAttribute("ServerLuckUntil") or 0) - os.time()
	refs.LuckChip.Visible = luckLeft > 0
	if luckLeft > 0 then
		refs.Luck.Text = "🍀 LUCK x2 " .. Util.formatTime(luckLeft)
	end
end

function Hud.setDot(name: string, visible: boolean)
	if dots[name] then
		dots[name].Visible = visible
	end
end

function Hud.setMusicOn(on: boolean)
	if refs.MusicFace then
		UIKit.setButtonColor(refs.MusicFace.Parent :: Frame, if on then Color3.fromRGB(90, 120, 230) else T.Gray)
	end
end

function Hud.update(newState)
	state = newState
	if lastCoins and state.Coins > lastCoins then
		refs.CoinsScale.Scale = 1.1
		TweenService:Create(refs.CoinsScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if lastCoins == nil then
		coinValue.Value = state.Coins -- první načtení bez animace
		refs.Coins.Text = Util.formatNumber(state.Coins)
	else
		TweenService:Create(coinValue, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = state.Coins }):Play()
	end
	lastCoins = state.Coins

	refs.Multiplier.Text = "⚡ " .. formatMultiplier(state.CoinMultiplier) .. " COINS"
	refs.RebirthChip.Visible = state.Rebirths > 0
	refs.Rebirths.Text = "♻️ " .. state.Rebirths

	local capacity = math.max(1, state.Capacity)
	local fraction = math.clamp(state.Sand / capacity, 0, 1)
	TweenService:Create(refs.SandFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.max(fraction, 0.02), 1) })
		:Play()
	if state.Sand >= capacity then
		refs.SandFill.BackgroundColor3 = T.Red
		refs.SandLabel.Text = if state.Passes.AutoSell
			then "⚡ AUTO SELLING..."
			else "🎒 FULL! SELL AT THE CAMP 💰"
	else
		refs.SandFill.BackgroundColor3 = T.Sand
		refs.SandLabel.Text = ("🏜️ %s / %s"):format(Util.formatNumber(state.Sand), Util.formatNumber(capacity))
	end
	local tool = Config.ToolsById[state.EquippedTool]
	local backpack = Config.BackpacksById[state.EquippedBackpack]
	refs.Tool.Text = ("%s %s   •   %s %s"):format(
		tool and tool.Icon or "",
		tool and tool.Name or "",
		backpack and backpack.Icon or "",
		backpack and backpack.Name or ""
	)
	refs.Hint.Visible = state.TotalSand < 150
	Hotbar.update(state)

	-- upozornění (červené tečky)
	local canBuy = false
	for _, item in Config.Tools do
		if not item.Pass and not state.OwnedTools[item.Id] and state.Coins >= item.Price then
			canBuy = true
		end
	end
	for _, item in Config.Backpacks do
		if not state.OwnedBackpacks[item.Id] and state.Coins >= item.Price then
			canBuy = true
		end
	end
	Hud.setDot("Shop", canBuy)
	Hud.setDot("Rebirth", state.Coins >= state.RebirthCost)
	local clockOffset = (state.ServerTime or os.time()) - os.time()
	Hud.setDot("Daily", os.time() + clockOffset >= (state.LastDaily or 0) + (state.DailyCooldown or 0))
	-- splněný úkol čeká na vyzvednutí
	local questReady = false
	local quests = state.Quests
	for _, quest in (type(quests) == "table" and quests.List) or {} do
		if not quest.Claimed and quest.Progress >= quest.Target then
			questReady = true
		end
	end
	Hud.setDot("Quests", questReady)
	-- volné místo pro mazlíčka, který zrovna nechodí s hráčem
	local owned = 0
	for _ in state.Pets or {} do
		owned += 1
	end
	local equipped = #(state.EquippedPets or {})
	Hud.setDot("Pets", equipped < (state.PetSlots or 0) and owned > equipped)
end

function Hud.setVisible(visible: boolean)
	root.Visible = visible
end

function Hud.build(gui: ScreenGui, context)
	ctx = context
	root = new(
		"Frame",
		{ Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui }
	)
	fxLayer = new(
		"Frame",
		{ Name = "Fx", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, Parent = gui }
	)
	coinValue = new("NumberValue", { Value = 0, Parent = gui })
	buildCurrency()
	buildMenu()
	buildBanner()
	buildSandBar()
	Hotbar.build(root, ctx)
	refs.Toasts = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(620, 260),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = refs.Toasts,
	})
	coinValue.Changed:Connect(function(value)
		refs.Coins.Text = Util.formatNumber(value)
	end)
	-- pulzování nápovědy
	task.spawn(function()
		while true do
			task.wait(0.6)
			if refs.Hint.Visible then
				TweenService:Create(
					refs.HintScale,
					TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true),
					{ Scale = 1.06 }
				):Play()
			end
		end
	end)
end

return Hud
