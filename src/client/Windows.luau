--[[
	Windows – okna hry: SHOP (3D náhledy nástrojů), STORE (Robux), REBIRTH,
	INDEX (artefakty), CODES, TOP (globální žebříček) a SETTINGS.
	Při otevřeném okně se pozadí rozmaže a ztmaví.
]]

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ToolFactory = require(ReplicatedStorage.Shared.ToolFactory)
local Util = require(ReplicatedStorage.Shared.Util)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local F = UIKit.Font
local new = UIKit.new

local Windows = {}

local player = Players.LocalPlayer
local ctx = nil
local gui: ScreenGui
local dim: Frame
local blur: BlurEffect
local windows = {}
local openName: string? = nil
local state = nil
local prices = {}
local spinners = {}

local TIER_COLORS = { T.Gray, Color3.fromRGB(176, 122, 74), T.Blue, T.Blue, T.Purple, T.Gold, T.Purple, T.Gold }

---------------------------------------------------------------------
-- Rám okna
---------------------------------------------------------------------

local function newWindow(name: string, title: string, color: Color3, size: Vector2): Frame
	local frame = new("Frame", {
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	UIKit.corner(frame, 26)
	UIKit.stroke(frame, 5)
	UIKit.shade(frame, 0.06)
	local scale = new("UIScale", { Parent = frame })

	local header = new(
		"Frame",
		{ Name = "Header", Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = color, ZIndex = 21, Parent = frame }
	)
	UIKit.corner(header, 26)
	UIKit.shade(header, 0.22)
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -26),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = header,
	})
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = T.Outline,
		BorderSizePixel = 0,
		ZIndex = 22,
		Parent = header,
	})
	UIKit.text({
		Text = title,
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(1, -120, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = F.Title,
		Stroke = 3,
		ZIndex = 23,
		Parent = header,
	})
	UIKit.button({
		Size = UDim2.fromOffset(56, 60),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Color = T.Red,
		Text = "X",
		Radius = 28,
		ZIndex = 24,
		Parent = header,
		OnClick = function()
			Windows.close()
		end,
	})
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 90),
		Size = UDim2.new(1, -40, 1, -106),
		ZIndex = 21,
		Parent = frame,
	})
	windows[name] = { Frame = frame, Scale = scale }
	return content
end

local function scroll(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local frame = new("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = T.Outline,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 22,
		Parent = parent,
	})
	UIKit.padding(frame, 6, 6)
	return frame
end

local function tabs(parent: Instance, list, onSelect)
	local bar =
		new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, ZIndex = 22, Parent = parent })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = bar })
	local holders = {}
	local function selectTab(key)
		for k, holder in holders do
			UIKit.setButtonColor(holder, if k == key then list[k].Color else T.Gray)
		end
		onSelect(key)
	end
	for key, info in list do
		holders[key] = UIKit.button({
			Size = UDim2.fromOffset(info.Width or 200, 54),
			Color = T.Gray,
			Text = info.Text,
			LayoutOrder = info.Order,
			ZIndex = 22,
			Parent = bar,
			OnClick = function()
				selectTab(key)
			end,
		})
	end
	return selectTab
end

---------------------------------------------------------------------
-- SHOP
---------------------------------------------------------------------

local function ownsItem(category: string, item): boolean
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
		ctx.toast("You already own " .. pass.Name, "success")
	elseif pass.Id == 0 then
		ctx.toast("This gamepass is not set up yet (developer: add its ID in Config)", "error")
	else
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end
end

local function promptProduct(key: string)
	local product = Config.Products[key]
	if product.Id == 0 then
		ctx.toast("This product is not set up yet (developer: add its ID in Config)", "error")
	else
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end
end

local function toolPreview(parent: Instance, toolId: string, icon: string)
	local box = new("Frame", {
		Size = UDim2.new(1, -16, 0, 128),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(125, 80, 40),
		ZIndex = 23,
		Parent = parent,
	})
	UIKit.corner(box, 14)
	UIKit.shade(box, 0.5)
	if toolId == "Hands" or toolId == "" then
		UIKit.text({
			Text = icon,
			Size = UDim2.fromScale(0.7, 0.8),
			Position = UDim2.fromScale(0.15, 0.1),
			Stroke = false,
			ZIndex = 24,
			Parent = box,
		})
		return box
	end
	local viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = 24,
		Parent = box,
	})
	local camera = new("Camera", { FieldOfView = 32, Parent = viewport })
	viewport.CurrentCamera = camera
	local model = ToolFactory.createModel(toolId)
	model.Parent = viewport
	local ok, cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	local center = if ok and cf then cf.Position else Vector3.zero
	local radius = if ok and size then math.max(size.X, size.Y, size.Z) else 4
	table.insert(
		spinners,
		{ Camera = camera, Center = center, Distance = radius * 1.7 + 1.5, Angle = math.random() * 6 }
	)
	return box
end

local function buildShop()
	local content = newWindow("Shop", "🛒 SHOP", T.Orange, Vector2.new(840, 580))
	local lists = {}
	local cards = {}
	local selectTab = tabs(content, {
		Tool = { Text = "⛏️ TOOLS", Color = T.Orange, Order = 1, Width = 220 },
		Backpack = { Text = "🎒 BACKPACKS", Color = T.Blue, Order = 2, Width = 260 },
	}, function(key)
		for k, list in lists do
			list.Visible = k == key
		end
	end)
	for _, category in { "Tool", "Backpack" } do
		local list = scroll(content, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 1, -66))
		list.Visible = category == "Tool"
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(240, 292),
			CellPadding = UDim2.fromOffset(14, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})
		lists[category] = list
		local items = if category == "Tool" then Config.Tools else Config.Backpacks
		for index, item in items do
			local tier = TIER_COLORS[index] or T.Gold
			local card = new("Frame", { BackgroundColor3 = T.Panel, LayoutOrder = index, ZIndex = 22, Parent = list })
			UIKit.corner(card, 18)
			local stroke = UIKit.stroke(card, 4, tier)
			if category == "Tool" then
				toolPreview(card, item.Id, item.Icon or "")
			else
				toolPreview(card, "", item.Icon or "🎒")
			end
			UIKit.text({
				Text = string.upper(item.Name),
				Position = UDim2.fromOffset(10, 142),
				Size = UDim2.new(1, -20, 0, 32),
				TextColor3 = T.Text,
				Font = F.Title,
				Stroke = false,
				ZIndex = 23,
				Parent = card,
			})
			local stats
			if category == "Tool" then
				stats = ("Size %.1f  •  Reach %d\n%.1f digs / sec"):format(item.Radius, item.Reach, 1 / item.Cooldown)
			else
				stats = ("Holds %s sand"):format(Util.formatNumber(item.Capacity))
			end
			UIKit.text({
				Text = stats,
				Position = UDim2.fromOffset(10, 176),
				Size = UDim2.new(1, -20, 0, 44),
				TextColor3 = T.SubText,
				Font = F.Small,
				Stroke = false,
				ZIndex = 23,
				Parent = card,
			})
			local holder, face = UIKit.button({
				Size = UDim2.new(1, -20, 0, 58),
				Position = UDim2.new(0, 10, 1, -66),
				Color = T.Green,
				Text = "",
				ZIndex = 23,
				Parent = card,
				OnClick = function()
					if not state then
						return
					end
					local owned = ownsItem(category, item)
					if category == "Tool" and item.Pass and not owned then
						promptPass(item.Pass)
						return
					end
					local remote = if owned then Remotes.EquipItem else Remotes.BuyItem
					local ok, message = remote:InvokeServer(category, item.Id)
					ctx.toast(message or "", if ok then "success" else "error")
					ctx.sfx(if ok and not owned then "Buy" elseif ok then "Click" else "Error")
				end,
			})
			table.insert(
				cards,
				{ Category = category, Item = item, Holder = holder, Face = face, Stroke = stroke, Tier = tier }
			)
		end
	end
	selectTab("Tool")

	windows.Shop.Tab = selectTab
	windows.Shop.Refresh = function()
		for _, c in cards do
			local item = c.Item
			local owned = ownsItem(c.Category, item)
			local equipped = (c.Category == "Tool" and state.EquippedTool == item.Id)
				or (c.Category == "Backpack" and state.EquippedBackpack == item.Id)
			if equipped then
				c.Face.Text = "✅ EQUIPPED"
				UIKit.setButtonColor(c.Holder, T.Gray)
				c.Stroke.Color = T.Green
			elseif owned then
				c.Face.Text = "EQUIP"
				UIKit.setButtonColor(c.Holder, T.Blue)
				c.Stroke.Color = c.Tier
			elseif item.Pass then
				local pass = Config.GamePasses[item.Pass]
				c.Face.Text = pass.Icon .. " " .. pass.Name .. " ONLY"
				UIKit.setButtonColor(c.Holder, T.Purple)
				c.Stroke.Color = T.Purple
			else
				c.Face.Text = "💰 " .. Util.formatNumber(item.Price)
				UIKit.setButtonColor(c.Holder, if state.Coins >= item.Price then T.Green else T.Gray)
				c.Stroke.Color = c.Tier
			end
		end
	end
end

---------------------------------------------------------------------
-- STORE (Robux)
---------------------------------------------------------------------

local PASS_COLORS = {
	VIP = T.Gold,
	DoubleCoins = T.Orange,
	AutoSell = Color3.fromRGB(255, 210, 40),
	TreasureRadar = T.Green,
	BigBackpack = T.Blue,
	FastDig = T.Red,
}
local RIBBONS = { VIP = "BEST", AutoSell = "POPULAR" }

local function buildStore()
	local content = newWindow("Store", "💎 STORE", T.Purple, Vector2.new(860, 600))
	local list = scroll(content, UDim2.new(), UDim2.fromScale(1, 1))
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local rows = {}

	local function header(order: number, text: string)
		UIKit.text({
			Text = text,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.Text,
			Font = F.Title,
			Stroke = false,
			ZIndex = 22,
			Parent = list,
		})
	end

	header(1, "⭐ GAMEPASSES – YOURS FOREVER")
	-- pevná výška mřížky (spolehlivější než AutomaticSize)
	local passRows = math.ceil(#Config.GamePassOrder / 2)
	local passGrid = new("Frame", {
		Size = UDim2.new(1, 0, 0, passRows * 182),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 22,
		Parent = list,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(384, 168),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = passGrid,
	})
	for index, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local color = PASS_COLORS[key] or T.Gold
		local card = new(
			"Frame",
			{ BackgroundColor3 = UIKit.lighten(color, 0.42), LayoutOrder = index, ZIndex = 22, Parent = passGrid }
		)
		UIKit.corner(card, 20)
		UIKit.stroke(card, 4)
		UIKit.shade(card, 0.15)
		local iconBox = new("Frame", {
			Size = UDim2.fromOffset(112, 112),
			Position = UDim2.fromOffset(14, 14),
			BackgroundColor3 = UIKit.darken(color, 0.25),
			ZIndex = 23,
			Parent = card,
		})
		UIKit.corner(iconBox, 56)
		UIKit.stroke(iconBox, 4)
		UIKit.text({
			Text = pass.Icon,
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.15, 0.15),
			Stroke = false,
			ZIndex = 24,
			Parent = iconBox,
		})
		UIKit.text({
			Text = string.upper(pass.Name),
			Position = UDim2.fromOffset(138, 12),
			Size = UDim2.new(1, -150, 0, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = F.Title,
			Stroke = 3,
			ZIndex = 23,
			Parent = card,
		})
		UIKit.text({
			Text = pass.Description,
			Position = UDim2.fromOffset(138, 52),
			Size = UDim2.new(1, -150, 0, 48),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = F.Small,
			TextColor3 = T.Outline,
			Stroke = false,
			ZIndex = 23,
			Parent = card,
		})
		local holder, face = UIKit.button({
			Size = UDim2.fromOffset(170, 52),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -10),
			Color = T.Green,
			Text = "",
			ZIndex = 23,
			Parent = card,
			OnClick = function()
				promptPass(key)
			end,
		})
		if RIBBONS[key] then
			local ribbon = new("Frame", {
				Size = UDim2.fromOffset(120, 32),
				Position = UDim2.new(1, -110, 0, -12),
				BackgroundColor3 = T.Red,
				Rotation = 8,
				ZIndex = 26,
				Parent = card,
			})
			UIKit.corner(ribbon, 10)
			UIKit.stroke(ribbon, 3)
			UIKit.text({
				Text = RIBBONS[key],
				Size = UDim2.fromScale(1, 1),
				Font = F.Title,
				ZIndex = 27,
				Parent = ribbon,
			})
		end
		table.insert(rows, { Kind = "Pass", Key = key, Holder = holder, Face = face, Price = pass.Price })
	end

	header(3, "⚡ BOOSTS & COINS")
	local productRows = math.ceil(#Config.ProductOrder / 4)
	local productGrid = new("Frame", {
		Size = UDim2.new(1, 0, 0, productRows * 233),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 22,
		Parent = list,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(186, 220),
		CellPadding = UDim2.fromOffset(13, 13),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = productGrid,
	})
	for index, key in Config.ProductOrder do
		local product = Config.Products[key]
		local color = if key == "ServerLuck" then T.Green else T.Gold
		local card =
			new("Frame", { BackgroundColor3 = T.PanelDark, LayoutOrder = index, ZIndex = 22, Parent = productGrid })
		UIKit.corner(card, 18)
		UIKit.stroke(card, 4, UIKit.darken(color, 0.2))
		UIKit.text({
			Text = product.Icon,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 70),
			Stroke = false,
			ZIndex = 23,
			Parent = card,
		})
		UIKit.text({
			Text = string.upper(product.Name),
			Position = UDim2.fromOffset(8, 84),
			Size = UDim2.new(1, -16, 0, 44),
			TextColor3 = T.Text,
			Font = F.Title,
			Stroke = false,
			ZIndex = 23,
			Parent = card,
		})
		local desc = if product.Coins
			then "+" .. Util.formatNumber(product.Coins) .. " coins\n× (rebirths + 1)"
			else "Rarer chests for\nEVERYONE!"
		UIKit.text({
			Text = desc,
			Position = UDim2.fromOffset(8, 128),
			Size = UDim2.new(1, -16, 0, 34),
			TextColor3 = T.SubText,
			Font = F.Small,
			Stroke = false,
			ZIndex = 23,
			Parent = card,
		})
		local holder, face = UIKit.button({
			Size = UDim2.new(1, -20, 0, 48),
			Position = UDim2.new(0, 10, 1, -56),
			Color = T.Green,
			Text = "",
			ZIndex = 23,
			Parent = card,
			OnClick = function()
				promptProduct(key)
			end,
		})
		table.insert(rows, { Kind = "Product", Key = key, Holder = holder, Face = face, Price = product.Price })
	end

	windows.Store.Refresh = function()
		for _, row in rows do
			if row.Kind == "Pass" and state.Passes[row.Key] then
				row.Face.Text = "✅ OWNED"
				UIKit.setButtonColor(row.Holder, T.Gray)
			else
				row.Face.Text = "R$ " .. tostring(prices[row.Kind .. row.Key] or row.Price)
				UIKit.setButtonColor(row.Holder, T.Green)
			end
		end
	end

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
	end)
end

---------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------

local function buildRebirth()
	local content = newWindow("Rebirth", "♻️ REBIRTH", T.Cyan, Vector2.new(620, 520))
	local multi = UIKit.text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 74),
		Font = F.Title,
		TextColor3 = T.Green,
		Stroke = 4,
		ZIndex = 22,
		Parent = content,
	})
	UIKit.text({
		Text = "COINS FOREVER",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 30),
		Font = F.Title,
		TextColor3 = T.Text,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})
	local info = new("Frame", {
		Position = UDim2.fromOffset(20, 116),
		Size = UDim2.new(1, -40, 0, 96),
		BackgroundColor3 = T.PanelDark,
		ZIndex = 22,
		Parent = content,
	})
	UIKit.corner(info, 16)
	UIKit.stroke(info, 3)
	UIKit.text({
		Text = "❌ Coins, tools & backpacks reset",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Red,
		Font = F.Body,
		Stroke = false,
		ZIndex = 23,
		Parent = info,
	})
	UIKit.text({
		Text = "✅ Artifacts, gamepasses & leaderboard stay",
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIKit.darken(T.Green, 0.2),
		Font = F.Body,
		Stroke = false,
		ZIndex = 23,
		Parent = info,
	})
	local _, fill, label = UIKit.bar({
		Position = UDim2.fromOffset(20, 230),
		Size = UDim2.new(1, -40, 0, 52),
		Color = T.Gold,
		Parent = content,
	})
	local holder = UIKit.button({
		Size = UDim2.fromOffset(320, 76),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Color = T.Cyan,
		Text = "♻️ REBIRTH",
		ZIndex = 22,
		Parent = content,
		OnClick = function()
			local ok, message = Remotes.Rebirth:InvokeServer()
			ctx.toast(message or "", if ok then "epic" else "error")
			if ok then
				ctx.sfx("Rebirth", 0.9)
				ctx.flash(T.Cyan, 0.6)
				ctx.bigPopup("♻️ REBIRTH!", T.Cyan)
				Windows.close()
			else
				ctx.sfx("Error")
			end
		end,
	})
	windows.Rebirth.Refresh = function()
		local per = Config.Rebirth.MultiplierPerRebirth
		multi.Text = ("x%.1f  ➜  x%.1f"):format(1 + state.Rebirths * per, 1 + (state.Rebirths + 1) * per)
		local fraction = math.clamp(state.Coins / math.max(1, state.RebirthCost), 0, 1)
		fill.Size = UDim2.fromScale(math.max(fraction, 0.02), 1)
		label.Text = ("💰 %s / %s"):format(Util.formatNumber(state.Coins), Util.formatNumber(state.RebirthCost))
		UIKit.setButtonColor(holder, if fraction >= 1 then T.Cyan else T.Gray)
	end
end

---------------------------------------------------------------------
-- INDEX (artefakty)
---------------------------------------------------------------------

local function buildIndex()
	local content = newWindow("Index", "📜 ARTIFACT INDEX", Color3.fromRGB(196, 130, 66), Vector2.new(860, 580))
	local summary = UIKit.text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = T.Text,
		Font = F.Title,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})
	local total = 0
	for _, name in Config.RarityOrder do
		total += Config.Rarities[name].Weight
	end
	local odds = {}
	for _, name in Config.RarityOrder do
		local weight = Config.Rarities[name].Weight
		if weight > 0 then
			table.insert(odds, ("%s %d%%"):format(name, math.floor(weight / total * 100 + 0.5)))
		end
	end
	UIKit.text({
		Text = "Chest odds: " .. table.concat(odds, " • ") .. "  (deeper = rarer, Mythic only in the ruins)",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = T.SubText,
		Font = F.Small,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})
	local grid = scroll(content, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 1, -66))
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(148, 186),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local cells = {}
	for index, artifact in Config.Artifacts do
		local rarity = Config.Rarities[artifact.Rarity]
		local cell = new(
			"Frame",
			{ BackgroundColor3 = UIKit.lighten(rarity.Color, 0.7), LayoutOrder = index, ZIndex = 22, Parent = grid }
		)
		UIKit.corner(cell, 16)
		UIKit.stroke(cell, 4, rarity.Color)
		UIKit.shade(cell, 0.12)
		local icon = UIKit.text({
			Text = "❓",
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 76),
			Stroke = false,
			ZIndex = 23,
			Parent = cell,
		})
		local name = UIKit.text({
			Text = "???",
			Position = UDim2.fromOffset(6, 92),
			Size = UDim2.new(1, -12, 0, 40),
			TextColor3 = T.Text,
			Font = F.Title,
			Stroke = false,
			ZIndex = 23,
			Parent = cell,
		})
		UIKit.text({
			Text = string.upper(artifact.Rarity) .. ("  +%d%%"):format(math.floor(artifact.Bonus * 100 + 0.5)),
			Position = UDim2.fromOffset(6, 140),
			Size = UDim2.new(1, -12, 0, 30),
			TextColor3 = rarity.Color,
			Font = F.Title,
			Stroke = 2,
			ZIndex = 23,
			Parent = cell,
		})
		local count = UIKit.text({
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 6),
			Size = UDim2.fromOffset(50, 26),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = F.Title,
			ZIndex = 24,
			Parent = cell,
		})
		cells[artifact.Id] = { Icon = icon, Name = name, Count = count, Artifact = artifact }
	end
	windows.Index.Refresh = function()
		local collected = 0
		for id, cell in cells do
			local owned = state.Artifacts[id] or 0
			if owned > 0 then
				collected += 1
				cell.Icon.Text = cell.Artifact.Icon
				cell.Name.Text = string.upper(cell.Artifact.Name)
				cell.Count.Text = "x" .. owned
			else
				cell.Icon.Text = "❓"
				cell.Name.Text = "???"
				cell.Count.Text = ""
			end
		end
		summary.Text = ("COLLECTED %d/%d  •  BONUS +%d%% COINS"):format(
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
	local content = newWindow("Codes", "🎟️ CODES", T.Pink, Vector2.new(560, 400))
	local box = new("TextBox", {
		PlaceholderText = "Enter code...",
		Text = "",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 70),
		Font = F.Title,
		TextScaled = true,
		TextColor3 = T.Text,
		PlaceholderColor3 = T.Gray,
		BackgroundColor3 = T.White,
		ZIndex = 22,
		Parent = content,
	})
	UIKit.corner(box, 16)
	UIKit.stroke(box, 4)
	UIKit.padding(box, 16, 10)
	UIKit.button({
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 86),
		Color = T.Green,
		Text = "REDEEM",
		ZIndex = 22,
		Parent = content,
		OnClick = function()
			if box.Text == "" then
				return
			end
			local ok, message = Remotes.RedeemCode:InvokeServer(box.Text)
			ctx.toast(message or "", if ok then "success" else "error")
			ctx.sfx(if ok then "Coin" else "Error")
			if ok then
				box.Text = ""
				ctx.flyCoins(8)
			end
		end,
	})
	UIKit.text({
		Text = "📱 New codes on our TikTok & Instagram!\nFollow @dunediggers",
		Position = UDim2.fromOffset(0, 176),
		Size = UDim2.new(1, 0, 0, 70),
		TextColor3 = T.SubText,
		Font = F.Body,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})
end

---------------------------------------------------------------------
-- TOP (globální žebříček)
---------------------------------------------------------------------

local function buildLeaderboard()
	local content = newWindow("Top", "🏆 TOP DIGGERS", T.Gold, Vector2.new(680, 640))
	local current = "Coins"
	local rows = {}
	local fields = { Coins = "TotalCoins", Sand = "TotalSand", Rebirths = "Rebirths" }
	local refresh
	local selectTab = tabs(content, {
		Coins = { Text = "💰 COINS", Color = T.Gold, Order = 1, Width = 200 },
		Sand = { Text = "🏜️ SAND", Color = T.Orange, Order = 2, Width = 200 },
		Rebirths = { Text = "♻️ REBIRTHS", Color = T.Cyan, Order = 3, Width = 220 },
	}, function(key)
		current = key
		if refresh then
			refresh()
		end
	end)
	local list = new("Frame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -130),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	})
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local medals = { "🥇", "🥈", "🥉" }
	for i = 1, Config.Leaderboard.Size do
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 37),
			BackgroundColor3 = if i <= 3 then UIKit.lighten(T.Gold, 0.55) else T.PanelDark,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = list,
		})
		UIKit.corner(row, 12)
		UIKit.stroke(row, 2)
		UIKit.text({
			Text = medals[i] or ("#" .. i),
			Size = UDim2.fromOffset(60, 37),
			Font = F.Title,
			TextColor3 = T.Text,
			Stroke = false,
			ZIndex = 23,
			Parent = row,
		})
		local name = UIKit.text({
			Text = "---",
			Position = UDim2.fromOffset(66, 4),
			Size = UDim2.new(1, -290, 1, -8),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.Text,
			Font = F.Body,
			Stroke = false,
			ZIndex = 23,
			Parent = row,
		})
		local value = UIKit.text({
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 4),
			Size = UDim2.fromOffset(200, 29),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = T.Orange,
			Font = F.Title,
			Stroke = 2,
			ZIndex = 23,
			Parent = row,
		})
		rows[i] = { Frame = row, Name = name, Value = value }
	end
	local mine = UIKit.text({
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 52),
		Font = F.Title,
		TextColor3 = T.Text,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})

	refresh = function()
		local data = {}
		local value = ReplicatedStorage:FindFirstChild("LeaderboardData")
		if value and value:IsA("StringValue") and value.Value ~= "" then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(value.Value)
			end)
			if ok and type(decoded) == "table" then
				data = decoded
			end
		end
		local entries = data[current] or {}
		for i, row in rows do
			local entry = entries[i]
			row.Name.Text = if entry then entry.Name else "---"
			row.Value.Text = if entry then Util.formatNumber(entry.Value) else ""
			row.Frame.BackgroundColor3 = if entry and entry.UserId == player.UserId
				then UIKit.lighten(T.Green, 0.5)
				elseif i <= 3 then UIKit.lighten(T.Gold, 0.55)
				else T.PanelDark
		end
		if state then
			mine.Text = "YOU: " .. Util.formatNumber(state[fields[current]] or 0)
		end
	end
	selectTab("Coins")
	windows.Top.Refresh = refresh
end

---------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------

local function buildSettings()
	local content = newWindow("Settings", "⚙️ SETTINGS", T.Gray, Vector2.new(600, 520))
	local current = { Music = 0.5, Sfx = 0.8, LowGfx = false, Popups = true }
	local setters = {}
	local function row(y: number, label: string)
		UIKit.text({
			Text = label,
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.fromOffset(250, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.Text,
			Font = F.Title,
			Stroke = false,
			ZIndex = 22,
			Parent = content,
		})
	end
	local function changed(key, value)
		current[key] = value
		ctx.settingsChanged(table.clone(current))
	end
	row(10, "🎵 MUSIC")
	local _, setMusic = UIKit.slider({
		Position = UDim2.fromOffset(270, 24),
		Size = UDim2.fromOffset(270, 24),
		Value = current.Music,
		Color = Color3.fromRGB(90, 120, 230),
		Parent = content,
		OnChanged = function(v)
			changed("Music", v)
		end,
	})
	row(84, "🔊 SOUNDS")
	local _, setSfx = UIKit.slider({
		Position = UDim2.fromOffset(270, 98),
		Size = UDim2.fromOffset(270, 24),
		Value = current.Sfx,
		Color = T.Orange,
		Parent = content,
		OnChanged = function(v)
			changed("Sfx", v)
		end,
	})
	row(158, "✨ LOW GRAPHICS")
	local _, setLow = UIKit.toggle({
		Position = UDim2.fromOffset(400, 156),
		Value = current.LowGfx,
		Parent = content,
		OnChanged = function(v)
			changed("LowGfx", v)
		end,
	})
	row(232, "💬 DIG NUMBERS")
	local _, setPopups = UIKit.toggle({
		Position = UDim2.fromOffset(400, 230),
		Value = current.Popups,
		Parent = content,
		OnChanged = function(v)
			changed("Popups", v)
		end,
	})
	UIKit.text({
		Text = "Music & sounds: original, made for Dune Diggers 🎶\nVersion " .. Config.Version,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 56),
		TextColor3 = T.SubText,
		Font = F.Small,
		Stroke = false,
		ZIndex = 22,
		Parent = content,
	})
	setters.apply = function(settings)
		for key, value in settings do
			current[key] = value
		end
		setMusic(current.Music)
		setSfx(current.Sfx)
		setLow(current.LowGfx)
		setPopups(current.Popups)
	end
	windows.Settings.Apply = setters.apply
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

function Windows.isOpen(): boolean
	return openName ~= nil
end

function Windows.close()
	if openName and windows[openName] then
		windows[openName].Frame.Visible = false
	end
	openName = nil
	dim.Visible = false
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
end

-- name může mít záložku: "Shop:Backpack"
function Windows.open(name: string)
	local base, tab = string.match(name, "^(%w+):?(%w*)$")
	base = base or name
	if openName == base and (tab == nil or tab == "") then
		Windows.close()
		return
	end
	if openName and windows[openName] then
		windows[openName].Frame.Visible = false
	end
	local window = windows[base]
	if not window then
		return
	end
	openName = base
	dim.Visible = true
	window.Frame.Visible = true
	window.Scale.Scale = 0.8
	TweenService
		:Create(window.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 14 }):Play()
	ctx.sfx("Open", 0.5)
	if tab and tab ~= "" and window.Tab then
		window.Tab(tab)
	end
	if state and window.Refresh then
		window.Refresh()
	end
end

function Windows.update(newState)
	state = newState
	if openName and windows[openName] and windows[openName].Refresh then
		windows[openName].Refresh()
	end
end

function Windows.applySettings(settings)
	if windows.Settings and windows.Settings.Apply then
		windows.Settings.Apply(settings)
	end
end

function Windows.build(screenGui: ScreenGui, context)
	gui = screenGui
	ctx = context
	blur = Instance.new("BlurEffect")
	blur.Name = "UIBlur"
	blur.Size = 0
	blur.Parent = Lighting
	dim = new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 15,
		Parent = gui,
	})
	dim.Activated:Connect(function()
		Windows.close()
	end)
	buildShop()
	buildStore()
	buildRebirth()
	buildIndex()
	buildCodes()
	buildLeaderboard()
	buildSettings()

	-- otáčení 3D náhledů nástrojů (jen když je obchod otevřený)
	RunService.RenderStepped:Connect(function(dt)
		if openName ~= "Shop" then
			return
		end
		for _, s in spinners do
			s.Angle += dt * 0.9
			local offset = Vector3.new(math.sin(s.Angle) * s.Distance, s.Distance * 0.3, math.cos(s.Angle) * s.Distance)
			s.Camera.CFrame = CFrame.lookAt(s.Center + offset, s.Center)
		end
	end)
	local lbValue = ReplicatedStorage:FindFirstChild("LeaderboardData")
	if lbValue then
		lbValue.Changed:Connect(function()
			if openName == "Top" and windows.Top.Refresh then
				windows.Top.Refresh()
			end
		end)
	end
end

return Windows
