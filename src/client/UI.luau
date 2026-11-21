--[[
	UI – celé uživatelské rozhraní hry, postavené kódem.
	HUD (mince, batoh, postup pouště), menu vlevo a okna:
	Shop, Store (Robux), Rebirth, Index (artefakty), Codes.

	Design se počítá pro rozlišení 1280x720 a automaticky se škáluje (UIScale),
	takže funguje na PC, tabletu i mobilu.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local Effects = require(script.Parent.Effects)

local UI = {}

local player = Players.LocalPlayer
local state = nil

local THEME = {
	Panel = Color3.fromRGB(255, 243, 220),
	PanelDark = Color3.fromRGB(242, 222, 186),
	Border = Color3.fromRGB(90, 55, 28),
	Text = Color3.fromRGB(85, 52, 25),
	SubText = Color3.fromRGB(130, 95, 60),
	White = Color3.new(1, 1, 1),
	Orange = Color3.fromRGB(255, 150, 40),
	Green = Color3.fromRGB(80, 195, 85),
	Blue = Color3.fromRGB(60, 150, 255),
	Purple = Color3.fromRGB(165, 85, 255),
	Cyan = Color3.fromRGB(60, 200, 230),
	Red = Color3.fromRGB(235, 70, 70),
	Gold = Color3.fromRGB(255, 200, 50),
	Gray = Color3.fromRGB(150, 140, 130),
	Sand = Color3.fromRGB(240, 200, 120),
	Dark = Color3.fromRGB(70, 45, 25),
}

local KIND_COLORS = {
	info = THEME.Dark,
	success = THEME.Green,
	error = THEME.Red,
	full = THEME.Red,
	epic = THEME.Purple,
	storm = THEME.Orange,
}

local gui: ScreenGui
local windows = {}
local openName: string? = nil
local refreshers = {}
local prices = {}

-- HUD prvky
local hud = {}

---------------------------------------------------------------------
-- Pomocníci pro stavbu UI
---------------------------------------------------------------------

local function create(className: string, props, children): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function border(parent: Instance, thickness: number, color: Color3?)
	return create("UIStroke", {
		Thickness = thickness,
		Color = color or THEME.Border,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function text(props): TextLabel
	local strokeThickness = props.Stroke
	props.Stroke = nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.White
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local label = create("TextLabel", props)
	if strokeThickness ~= false then
		create("UIStroke", {
			Thickness = strokeThickness or 2,
			Color = THEME.Border,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

local function makeButton(props, onClick: () -> ()): TextButton
	props.AutoButtonColor = false
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.White
	props.TextStrokeColor3 = THEME.Border
	props.TextStrokeTransparency = 0.1
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local button = create("TextButton", props)
	corner(button, 12)
	border(button, 3)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = button,
	})
	local scale = create("UIScale", { Parent = button })
	local quick = TweenInfo.new(0.08)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		Effects.playSound("Click", 0.25, 1.4)
		onClick()
	end)
	return button
end

local function makeBar(parent: Instance, position: UDim2, size: UDim2, color: Color3)
	local background = create("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(70, 45, 25),
		Parent = parent,
	})
	corner(background, 10)
	border(background, 3)
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = background,
	})
	corner(fill, 10)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		Rotation = 90,
		Parent = fill,
	})
	local label = text({
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		Text = "",
		ZIndex = 3,
		Parent = background,
	})
	return background, fill, label
end

local function makeScroll(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local scroll = create("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = THEME.Border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 3),
		PaddingTop = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 6),
		Parent = scroll,
	})
	return scroll
end

local function makeRow(parent: Instance, order: number, icon: string, title: string, description: string): Frame
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundColor3 = THEME.PanelDark,
		LayoutOrder = order,
		Parent = parent,
	})
	corner(row, 12)
	border(row, 2)
	text({
		Text = icon,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(10, 10),
		Stroke = false,
		Parent = row,
	})
	text({
		Text = title,
		Size = UDim2.new(1, -270, 0, 32),
		Position = UDim2.fromOffset(76, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Text,
		Stroke = false,
		Parent = row,
	})
	text({
		Text = description,
		Size = UDim2.new(1, -270, 0, 28),
		Position = UDim2.fromOffset(76, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.SubText,
		Font = Enum.Font.GothamMedium,
		Stroke = false,
		Parent = row,
	})
	return row
end

local function rowButton(row: Frame, onClick: () -> ()): TextButton
	return makeButton({
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(170, 52),
		BackgroundColor3 = THEME.Green,
		Parent = row,
	}, onClick)
end

local function sectionHeader(parent: Instance, order: number, title: string)
	text({
		Text = title,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Text,
		Stroke = false,
		Parent = parent,
	})
end

local function formatMultiplier(value: number): string
	local textValue = string.format("%.2f", value)
	textValue = textValue:gsub("0+$", ""):gsub("%.$", "")
	return "x" .. textValue
end

---------------------------------------------------------------------
-- Okna
---------------------------------------------------------------------

local function newWindow(name: string, title: string, color: Color3, size: Vector2?): Frame
	local windowSize = size or Vector2.new(700, 470)
	local frame = create("Frame", {
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = UDim2.fromOffset(windowSize.X, windowSize.Y),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	corner(frame, 18)
	border(frame, 4)
	local scale = create("UIScale", { Parent = frame })

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		Parent = frame,
	})
	corner(header, 18)
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	})
	text({
		Text = title,
		Size = UDim2.new(1, -120, 1, -14),
		Position = UDim2.fromOffset(20, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 3,
		ZIndex = 2,
		Parent = header,
	})
	makeButton({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = THEME.Red,
		ZIndex = 2,
		Parent = header,
	}, function()
		UI.close()
	end)

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 1, -84),
		Parent = frame,
	})
	windows[name] = { Frame = frame, Scale = scale }
	return content
end

function UI.close()
	if openName and windows[openName] then
		windows[openName].Frame.Visible = false
	end
	openName = nil
end

function UI.open(name: string)
	if openName == name then
		UI.close()
		return
	end
	UI.close()
	local window = windows[name]
	if not window then
		return
	end
	openName = name
	window.Frame.Visible = true
	window.Scale.Scale = 0.85
	TweenService
		:Create(window.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	if state and refreshers[name] then
		refreshers[name]()
	end
end

---------------------------------------------------------------------
-- Notifikace
---------------------------------------------------------------------

local toastContainer: Frame
local toastCounter = 0

function UI.toast(message: string, kind: string?)
	kind = kind or "info"
	local color = KIND_COLORS.info
	if string.sub(kind :: string, 1, 7) == "rarity:" then
		local rarity = Config.Rarities[string.sub(kind :: string, 8)]
		color = if rarity then rarity.Color else THEME.Gold
	elseif KIND_COLORS[kind :: string] then
		color = KIND_COLORS[kind :: string]
	end

	toastCounter += 1
	local toast = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = color,
		LayoutOrder = toastCounter,
		Parent = toastContainer,
	})
	corner(toast, 12)
	border(toast, 3)
	local scale = create("UIScale", { Scale = 0.5, Parent = toast })
	text({
		Text = message,
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		Stroke = 2,
		Parent = toast,
	})
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	-- max 4 notifikace najednou
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
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

-- Velký nápis uprostřed obrazovky (např. po prodeji)
function UI.bigPopup(message: string, color: Color3)
	local label = text({
		Text = message,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 80),
		TextColor3 = color,
		Stroke = 4,
		ZIndex = 30,
		Parent = gui,
	})
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	local scale = create("UIScale", { Scale = 0.4, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(0.8, function()
		local info = TweenInfo.new(0.6)
		TweenService:Create(label, info, { Position = UDim2.fromScale(0.5, 0.35), TextTransparency = 1 }):Play()
		if labelStroke then
			TweenService:Create(labelStroke, info, { Transparency = 1 }):Play()
		end
		task.wait(0.65)
		label:Destroy()
	end)
end

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------

local function buildHud()
	-- Mince vlevo nahoře
	local stats = create("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(270, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local coinsPill = create("Frame", {
		Size = UDim2.fromOffset(270, 54),
		BackgroundColor3 = THEME.Dark,
		BackgroundTransparency = 0.15,
		Parent = stats,
	})
	corner(coinsPill, 27)
	border(coinsPill, 3, THEME.Gold)
	hud.CoinsScale = create("UIScale", { Parent = coinsPill })
	text({
		Text = "💰",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(8, 5),
		Stroke = false,
		Parent = coinsPill,
	})
	hud.Coins = text({
		Text = "0",
		Size = UDim2.new(1, -70, 1, -12),
		Position = UDim2.fromOffset(58, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Gold,
		Stroke = 2,
		Parent = coinsPill,
	})
	hud.Multiplier = text({
		Text = "x1 coins",
		Size = UDim2.fromOffset(270, 26),
		Position = UDim2.fromOffset(6, 58),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})
	hud.Luck = text({
		Text = "",
		Size = UDim2.fromOffset(270, 26),
		Position = UDim2.fromOffset(6, 86),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 255, 120),
		Visible = false,
		Parent = stats,
	})

	-- Postup pouště nahoře uprostřed
	local desert = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(400, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	hud.DesertTitle = text({ Text = "DESERT CLEARED: 0%", Size = UDim2.new(1, 0, 0, 24), Parent = desert })
	local _, desertFill = makeBar(desert, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 18), THEME.Orange)
	hud.DesertFill = desertFill
	hud.Storm = text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 48),
		Parent = desert,
	})

	-- Batoh dole uprostřed
	local sand = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(460, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	hud.Tool = text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Parent = sand })
	local _, sandFill, sandLabel = makeBar(sand, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 40), THEME.Sand)
	hud.SandFill = sandFill
	hud.SandLabel = sandLabel
	hud.Hint = text({
		Text = "👆 Hold click / tap to dig!  Sell sand on the golden pad at camp 💰",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(640, 30),
		TextColor3 = THEME.Gold,
		Stroke = 3,
		Visible = false,
		Parent = sand,
	})

	-- Menu vlevo nahoře (mřížka 2x3 – na mobilu nepřekáží joysticku)
	local menu = create("Frame", {
		Position = UDim2.fromOffset(14, 146),
		Size = UDim2.fromOffset(2 * 132 + 8, 3 * 54 + 2 * 8),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(132, 54),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local buttons = {
		{
			"🛒 SHOP",
			THEME.Orange,
			function()
				UI.open("Shop")
			end,
		},
		{
			"💎 STORE",
			THEME.Purple,
			function()
				UI.open("Store")
			end,
		},
		{
			"♻️ REBIRTH",
			THEME.Cyan,
			function()
				UI.open("Rebirth")
			end,
		},
		{
			"📜 INDEX",
			Color3.fromRGB(190, 130, 70),
			function()
				UI.open("Index")
			end,
		},
		{
			"🎁 CODES",
			THEME.Green,
			function()
				UI.open("Codes")
			end,
		},
		{
			"⛺ CAMP",
			THEME.Blue,
			function()
				UI.close()
				Remotes.TeleportCamp:FireServer()
			end,
		},
	}
	for index, info in buttons do
		makeButton({
			Text = info[1],
			Size = UDim2.fromOffset(132, 54),
			BackgroundColor3 = info[2],
			LayoutOrder = index,
			Parent = menu,
		}, info[3])
	end

	-- Kontejner notifikací
	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(600, 260),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toastContainer,
	})
end

local function updateDesert()
	local cleared = workspace:GetAttribute("DesertCleared") or 0
	local phase = workspace:GetAttribute("StormPhase") or "Calm"
	local stormIn = workspace:GetAttribute("StormIn") or 0
	hud.DesertTitle.Text = "DESERT CLEARED: " .. Util.formatPercent(cleared)
	hud.DesertFill.Size = UDim2.fromScale(math.clamp(cleared / Config.Sandstorm.ClearedThreshold, 0, 1), 1)
	if phase == "Warning" then
		hud.Storm.Text = ("⚠️ SANDSTORM IN %ds! ⚠️"):format(stormIn)
		hud.Storm.TextColor3 = Color3.fromRGB(255, 110, 80)
	elseif phase == "Active" then
		hud.Storm.Text = "🌪️ SANDSTORM! The desert is being buried..."
		hud.Storm.TextColor3 = Color3.fromRGB(255, 150, 60)
	else
		hud.Storm.Text = ("🌪️ Sandstorm in %s or at %d%% cleared"):format(
			Util.formatTime(stormIn),
			math.floor(Config.Sandstorm.ClearedThreshold * 100)
		)
		hud.Storm.TextColor3 = THEME.White
	end

	local luckUntil = workspace:GetAttribute("ServerLuckUntil") or 0
	local luckLeft = luckUntil - os.time()
	hud.Luck.Visible = luckLeft > 0
	if luckLeft > 0 then
		hud.Luck.Text = "🍀 SERVER LUCK x2 – " .. Util.formatTime(luckLeft)
	end
end

local lastCoins = nil

local function updateHud()
	if not state then
		return
	end
	hud.Coins.Text = Util.formatNumber(state.Coins)
	if lastCoins and state.Coins > lastCoins then
		hud.CoinsScale.Scale = 1.12
		TweenService:Create(hud.CoinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = state.Coins

	local multiplierText = formatMultiplier(state.CoinMultiplier) .. " coins"
	if state.Rebirths > 0 then
		multiplierText ..= "  •  ♻️ " .. state.Rebirths
	end
	hud.Multiplier.Text = multiplierText

	local capacity = math.max(1, state.Capacity)
	local fraction = math.clamp(state.Sand / capacity, 0, 1)
	hud.SandFill.Size = UDim2.fromScale(fraction, 1)
	if state.Sand >= capacity then
		hud.SandFill.BackgroundColor3 = THEME.Red
		hud.SandLabel.Text = if state.Passes.AutoSell then "⚡ AUTO SELLING..." else "🎒 FULL! Sell at camp 💰"
	else
		hud.SandFill.BackgroundColor3 = THEME.Sand
		hud.SandLabel.Text = ("🏜️ %s / %s"):format(Util.formatNumber(state.Sand), Util.formatNumber(capacity))
	end

	local tool = Config.ToolsById[state.EquippedTool]
	local backpack = Config.BackpacksById[state.EquippedBackpack]
	hud.Tool.Text = ("%s %s   •   %s %s"):format(
		tool and tool.Icon or "",
		tool and tool.Name or "",
		backpack and backpack.Icon or "",
		backpack and backpack.Name or ""
	)
	hud.Hint.Visible = state.TotalSand < 150
end

---------------------------------------------------------------------
-- SHOP (nástroje a batohy za mince)
---------------------------------------------------------------------

local function isOwned(category: string, item): boolean
	if not state then
		return false
	end
	if category == "Tool" then
		if item.Pass then
			return state.Passes[item.Pass] == true
		end
		return state.OwnedTools[item.Id] == true
	end
	return state.OwnedBackpacks[item.Id] == true
end

local function promptPass(key: string)
	local pass = Config.GamePasses[key]
	if not pass then
		return
	end
	if state and state.Passes[key] then
		UI.toast("You already own " .. pass.Name, "info")
		return
	end
	if pass.Id == 0 then
		UI.toast("This gamepass is not set up yet (developer: add its ID in Config)", "error")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function promptProduct(key: string)
	local product = Config.Products[key]
	if not product then
		return
	end
	if product.Id == 0 then
		UI.toast("This product is not set up yet (developer: add its ID in Config)", "error")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

local function buildShop()
	local content = newWindow("Shop", "🛒 SHOP", THEME.Orange)
	local rows = {}
	local lists = {}
	local tabButtons = {}

	local function showTab(category: string)
		for cat, list in lists do
			list.Visible = cat == category
		end
		for cat, button in tabButtons do
			button.BackgroundColor3 = if cat == category then THEME.Orange else THEME.Gray
		end
	end

	local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = content })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = tabs })

	for _, category in { "Tool", "Backpack" } do
		tabButtons[category] = makeButton({
			Text = if category == "Tool" then "⛏️ TOOLS" else "🎒 BACKPACKS",
			Size = UDim2.fromOffset(190, 44),
			BackgroundColor3 = THEME.Gray,
			Parent = tabs,
		}, function()
			showTab(category)
		end)

		local list = makeScroll(content, UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -54))
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		lists[category] = list

		local items = if category == "Tool" then Config.Tools else Config.Backpacks
		for index, item in items do
			local description
			if category == "Tool" then
				description = ("Dig size %.1f • Reach %d • %.1f digs/s"):format(
					item.Radius,
					item.Reach,
					1 / item.Cooldown
				)
			else
				description = ("Holds %s sand"):format(Util.formatNumber(item.Capacity))
			end
			local row = makeRow(list, index, item.Icon or "❔", item.Name, description)
			local button = rowButton(row, function()
				if not state then
					return
				end
				local owned = isOwned(category, item)
				if category == "Tool" and item.Pass and not owned then
					promptPass(item.Pass)
					return
				end
				local remote = if owned then Remotes.EquipItem else Remotes.BuyItem
				local ok, message = remote:InvokeServer(category, item.Id)
				UI.toast(message or "", if ok then "success" else "error")
				if ok and not owned then
					Effects.playSound("Sell", 0.6, 1.2)
				end
			end)
			table.insert(rows, { Category = category, Item = item, Button = button })
		end
	end
	showTab("Tool")

	refreshers.Shop = function()
		for _, row in rows do
			local item, button = row.Item, row.Button
			local owned = isOwned(row.Category, item)
			local equipped = (row.Category == "Tool" and state.EquippedTool == item.Id)
				or (row.Category == "Backpack" and state.EquippedBackpack == item.Id)
			if equipped then
				button.Text = "EQUIPPED"
				button.BackgroundColor3 = THEME.Gray
			elseif owned then
				button.Text = "EQUIP"
				button.BackgroundColor3 = THEME.Blue
			elseif item.Pass then
				local pass = Config.GamePasses[item.Pass]
				button.Text = pass.Icon .. " " .. pass.Name
				button.BackgroundColor3 = THEME.Purple
			else
				button.Text = "💰 " .. Util.formatNumber(item.Price)
				button.BackgroundColor3 = if state.Coins >= item.Price then THEME.Green else THEME.Gray
			end
		end
	end
end

---------------------------------------------------------------------
-- STORE (gamepassy a produkty za Robux)
---------------------------------------------------------------------

local function buildStore()
	local content = newWindow("Store", "💎 STORE", THEME.Purple)
	local list = makeScroll(content, UDim2.new(), UDim2.fromScale(1, 1))
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local rows = {}

	sectionHeader(list, 0, "⭐ GAMEPASSES – yours forever")
	for index, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local row = makeRow(list, index, pass.Icon, pass.Name, pass.Description)
		local button = rowButton(row, function()
			promptPass(key)
		end)
		table.insert(rows, { Kind = "Pass", Key = key, Button = button, Price = pass.Price })
	end

	sectionHeader(list, 100, "⚡ BOOSTS & COINS")
	for index, key in Config.ProductOrder do
		local product = Config.Products[key]
		local description
		if product.Coins then
			description = ("+%s coins (more after every rebirth!)"):format(Util.formatNumber(product.Coins))
		else
			description = "Rarer chests for EVERYONE in the server!"
		end
		local row = makeRow(list, 100 + index, product.Icon, product.Name, description)
		local button = rowButton(row, function()
			promptProduct(key)
		end)
		table.insert(rows, { Kind = "Product", Key = key, Button = button, Price = product.Price })
	end

	refreshers.Store = function()
		for _, row in rows do
			local owned = row.Kind == "Pass" and state.Passes[row.Key]
			if owned then
				row.Button.Text = "✅ OWNED"
				row.Button.BackgroundColor3 = THEME.Gray
			else
				row.Button.Text = "R$ " .. tostring(prices[row.Kind .. row.Key] or row.Price)
				row.Button.BackgroundColor3 = THEME.Green
			end
		end
	end

	-- Skutečné ceny z Robloxu (když jsou ID vyplněná)
	task.spawn(function()
		for key, pass in Config.GamePasses do
			if pass.Id ~= 0 then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(pass.Id, Enum.InfoType.GamePass)
				end)
				if ok and info and info.PriceInRobux then
					prices["Pass" .. key] = info.PriceInRobux
				end
			end
		end
		for key, product in Config.Products do
			if product.Id ~= 0 then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(product.Id, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					prices["Product" .. key] = info.PriceInRobux
				end
			end
		end
		if state and openName == "Store" then
			refreshers.Store()
		end
	end)
end

---------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------

local function buildRebirth()
	local content = newWindow("Rebirth", "♻️ REBIRTH", THEME.Cyan, Vector2.new(560, 420))
	local title =
		text({ Text = "", Size = UDim2.new(1, 0, 0, 40), TextColor3 = THEME.Text, Stroke = false, Parent = content })
	text({
		Text = "Resets your coins, tools and backpacks.\nYou KEEP artifacts and gamepasses.",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 46),
		TextColor3 = THEME.SubText,
		Font = Enum.Font.GothamMedium,
		Stroke = false,
		Parent = content,
	})
	local multiplier = text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 110),
		TextColor3 = THEME.Green,
		Parent = content,
	})
	local _, fill, label = makeBar(content, UDim2.fromOffset(0, 168), UDim2.new(1, 0, 0, 42), THEME.Gold)
	local button = makeButton({
		Text = "♻️ REBIRTH",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(280, 62),
		BackgroundColor3 = THEME.Cyan,
		Parent = content,
	}, function()
		local ok, message = Remotes.Rebirth:InvokeServer()
		UI.toast(message or "", if ok then "epic" else "error")
		if ok then
			UI.bigPopup("♻️ REBIRTH!", THEME.Cyan)
			UI.close()
		end
	end)

	refreshers.Rebirth = function()
		local per = Config.Rebirth.MultiplierPerRebirth
		title.Text = ("Rebirth %d  →  %d"):format(state.Rebirths, state.Rebirths + 1)
		multiplier.Text = ("Rebirth bonus: x%.1f  →  x%.1f coins"):format(
			1 + state.Rebirths * per,
			1 + (state.Rebirths + 1) * per
		)
		local fraction = math.clamp(state.Coins / math.max(1, state.RebirthCost), 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
		label.Text = ("💰 %s / %s"):format(Util.formatNumber(state.Coins), Util.formatNumber(state.RebirthCost))
		button.BackgroundColor3 = if fraction >= 1 then THEME.Cyan else THEME.Gray
	end
end

---------------------------------------------------------------------
-- INDEX (sbírka artefaktů)
---------------------------------------------------------------------

local function buildIndex()
	local content = newWindow("Index", "📜 ARTIFACT INDEX", Color3.fromRGB(190, 130, 70))
	local summary = text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = THEME.Text,
		Stroke = false,
		Parent = content,
	})
	-- Šance na raritu truhly (transparentnost – pravidla Robloxu pro náhodné odměny)
	local totalWeight = 0
	for _, name in Config.RarityOrder do
		totalWeight += Config.Rarities[name].Weight
	end
	local oddsParts = {}
	for _, name in Config.RarityOrder do
		local weight = Config.Rarities[name].Weight
		if weight > 0 then
			table.insert(oddsParts, ("%s %d%%"):format(name, math.floor(weight / totalWeight * 100 + 0.5)))
		end
	end
	text({
		Text = "Chest odds: " .. table.concat(oddsParts, " • ") .. " (deeper = rarer, Mythic only in ruins)",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 34),
		TextColor3 = THEME.SubText,
		Font = Enum.Font.GothamMedium,
		Stroke = false,
		Parent = content,
	})
	local grid = makeScroll(content, UDim2.fromOffset(0, 60), UDim2.new(1, 0, 1, -60))
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(146, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cells = {}
	for index, artifact in Config.Artifacts do
		local rarity = Config.Rarities[artifact.Rarity]
		local cell = create("Frame", { BackgroundColor3 = THEME.PanelDark, LayoutOrder = index, Parent = grid })
		corner(cell, 14)
		border(cell, 3, rarity.Color)
		local icon = text({
			Text = "❓",
			Size = UDim2.new(1, 0, 0, 64),
			Position = UDim2.fromOffset(0, 8),
			Stroke = false,
			Parent = cell,
		})
		local name = text({
			Text = "???",
			Size = UDim2.new(1, -10, 0, 30),
			Position = UDim2.fromOffset(5, 76),
			TextColor3 = THEME.Text,
			Stroke = false,
			Parent = cell,
		})
		text({
			Text = string.upper(artifact.Rarity) .. ("  +%d%%"):format(math.floor(artifact.Bonus * 100 + 0.5)),
			Size = UDim2.new(1, -10, 0, 22),
			Position = UDim2.fromOffset(5, 110),
			TextColor3 = rarity.Color,
			Stroke = 1.5,
			Parent = cell,
		})
		local count = text({
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 4),
			Size = UDim2.fromOffset(50, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = cell,
		})
		cells[artifact.Id] = { Icon = icon, Name = name, Count = count, Artifact = artifact }
	end

	refreshers.Index = function()
		local collected = 0
		for id, cell in cells do
			local owned = state.Artifacts[id] or 0
			if owned > 0 then
				collected += 1
				cell.Icon.Text = cell.Artifact.Icon
				cell.Name.Text = cell.Artifact.Name
				cell.Count.Text = "x" .. owned
			else
				cell.Icon.Text = "❓"
				cell.Name.Text = "???"
				cell.Count.Text = ""
			end
		end
		summary.Text = ("Collected %d/%d  •  Artifact bonus: +%d%% coins"):format(
			collected,
			#Config.Artifacts,
			math.floor(state.ArtifactBonus * 100 + 0.5)
		)
	end
end

---------------------------------------------------------------------
-- CODES
---------------------------------------------------------------------

local function buildCodes()
	local content = newWindow("Codes", "🎁 CODES", THEME.Green, Vector2.new(480, 330))
	local box = create("TextBox", {
		PlaceholderText = "Enter code...",
		Text = "",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 58),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Gray,
		BackgroundColor3 = THEME.White,
		Parent = content,
	})
	corner(box, 12)
	border(box, 3)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = box,
	})
	makeButton({
		Text = "REDEEM",
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 70),
		BackgroundColor3 = THEME.Green,
		Parent = content,
	}, function()
		local code = box.Text
		if code == "" then
			return
		end
		local ok, message = Remotes.RedeemCode:InvokeServer(code)
		UI.toast(message or "", if ok then "success" else "error")
		if ok then
			box.Text = ""
			Effects.playSound("Sell", 0.6, 1.1)
		end
	end)
	text({
		Text = "📱 New codes on our TikTok & Instagram!",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 142),
		TextColor3 = THEME.SubText,
		Font = Enum.Font.GothamMedium,
		Stroke = false,
		Parent = content,
	})
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

function UI.update(newState)
	state = newState
	updateHud()
	if openName and refreshers[openName] then
		refreshers[openName]()
	end
end

function UI.getState()
	return state
end

function UI.init()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = create("ScreenGui", {
		Name = "DuneDiggersUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	-- Automatické škálování podle velikosti obrazovky
	local uiScale = create("UIScale", { Parent = gui })
	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.5)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	buildHud()
	buildShop()
	buildStore()
	buildRebirth()
	buildIndex()
	buildCodes()

	for _, attribute in { "DesertCleared", "StormPhase", "StormIn", "ServerLuckUntil" } do
		workspace:GetAttributeChangedSignal(attribute):Connect(updateDesert)
	end
	updateDesert()
	task.spawn(function()
		while true do
			task.wait(1)
			updateDesert()
		end
	end)
end

return UI
