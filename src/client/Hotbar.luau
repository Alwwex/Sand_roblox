--[[
	Hotbar – vlastní výběr nástrojů (místo výchozího Roblox hotbaru).

	- Sloty pro všechny vlastněné nástroje s 3D náhledem, číslem klávesy a barvou podle úrovně.
	- Klávesy 1–9 / kliknutí / tap = přepnutí nástroje. Znovu stejný slot = schovat / vytáhnout nástroj.
	- Ovladač: LB / RB přepíná mezi nástroji.
	- Poslední slot ukazuje další nástroj k odemčení (cena) a otevře obchod.
	- Při přepnutí se nad lištou ukáže název nástroje.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ToolFactory = require(ReplicatedStorage.Shared.ToolFactory)
local Util = require(ReplicatedStorage.Shared.Util)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local new = UIKit.new

local Hotbar = {}

local SLOT = 78
local GAP = 10
local KEYS = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8, Nine = 9 }
local TIER_COLORS = { T.Gray, Color3.fromRGB(176, 122, 74), T.Blue, T.Blue, T.Purple, T.Gold, T.Purple, T.Gold }

local player = Players.LocalPlayer
local ctx = nil
local bar: Frame
local nameLabel: TextLabel
local nameScale: UIScale
local state = nil
local slots = {} -- { {ToolId, Holder, Face, Ring, Lift} }
local signature = ""
local holding = false
local nameToken = 0

---------------------------------------------------------------------
-- Pomocníci
---------------------------------------------------------------------

local function ownsTool(tool): boolean
	if not state then
		return false
	end
	if tool.Pass then
		return state.Passes[tool.Pass] == true
	end
	return state.OwnedTools[tool.Id] == true
end

local function heldTool(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("DigToolId") then
		return tool
	end
	return nil
end

local function toolPreview(parent: Instance, tool, zIndex: number)
	if tool.Id == "Hands" then
		UIKit.text({
			Text = tool.Icon or "✋",
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.15, 0.1),
			Stroke = false,
			ZIndex = zIndex,
			Parent = parent,
		})
		return
	end
	local viewport = new("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 2),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 165, 155),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = zIndex,
		Parent = parent,
	})
	local camera = new("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local model = ToolFactory.createModel(tool.Id)
	model.Parent = viewport
	local ok, cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	local center = if ok and cf then cf.Position else Vector3.zero
	local radius = if ok and size then math.max(size.X, size.Y, size.Z) else 4
	local distance = radius * 1.55 + 1
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.55, distance * 0.35, -distance * 0.75), center)
end

function Hotbar.showName(text: string, color: Color3?)
	nameToken += 1
	local token = nameToken
	nameLabel.Text = text
	nameLabel.TextColor3 = color or T.White
	nameLabel.Visible = true
	nameLabel.TextTransparency = 0
	nameScale.Scale = 0.7
	TweenService:Create(nameScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(1.6, function()
		if token == nameToken then
			nameLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- Výběr nástroje
---------------------------------------------------------------------

local function selectTool(toolId: string)
	if not state then
		return
	end
	local tool = Config.ToolsById[toolId]
	if not tool then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if toolId == state.EquippedTool then
		-- stejný nástroj: schovat / vytáhnout
		if not humanoid then
			return
		end
		if heldTool() then
			humanoid:UnequipTools()
		else
			local backpack = player:FindFirstChildOfClass("Backpack")
			for _, item in if backpack then backpack:GetChildren() else {} do
				if item:IsA("Tool") and item:GetAttribute("DigToolId") then
					humanoid:EquipTool(item)
					break
				end
			end
			Hotbar.showName(string.upper(tool.Name), T.Gold)
		end
		ctx.sfx("Click", 0.5)
		return
	end
	Hotbar.showName(string.upper(tool.Name), T.Gold)
	ctx.sfx("Open", 0.5, 1.2)
	task.spawn(function()
		local ok, message = Remotes.EquipItem:InvokeServer("Tool", toolId)
		if not ok then
			ctx.toast(message or "", "error")
		end
	end)
end

local function cycle(direction: number)
	if #slots == 0 or not state then
		return
	end
	local owned = {}
	for _, slot in slots do
		if not slot.Locked then
			table.insert(owned, slot.ToolId)
		end
	end
	local index = table.find(owned, state.EquippedTool) or 1
	index = ((index - 1 + direction) % #owned) + 1
	selectTool(owned[index])
end

---------------------------------------------------------------------
-- Stavba slotů
---------------------------------------------------------------------

local function clearSlots()
	for _, slot in slots do
		slot.Container:Destroy()
	end
	table.clear(slots)
end

local function buildSlots()
	clearSlots()
	local ownedTools = {}
	local nextLocked = nil
	for _, tool in Config.Tools do
		if ownsTool(tool) then
			table.insert(ownedTools, tool)
		elseif not nextLocked and not tool.Pass then
			nextLocked = tool
		end
	end
	while #ownedTools > 9 do
		table.remove(ownedTools, 1)
	end

	for index, tool in ownedTools do
		local tier = TIER_COLORS[tool.Index] or T.Gold
		-- obal slotu (dítě layoutu); tlačítko uvnitř se dá "zvednout"
		local container = new("Frame", {
			Name = "Slot" .. index,
			Size = UDim2.fromOffset(SLOT, SLOT + 14),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = bar,
		})
		local holder, face = UIKit.button({
			Name = "Button",
			Size = UDim2.fromOffset(SLOT, SLOT + 6),
			Position = UDim2.fromOffset(0, 8),
			Color = UIKit.lighten(tier, 0.55),
			Text = "",
			Radius = 16,
			Parent = container,
			OnClick = function()
				selectTool(tool.Id)
			end,
		})
		toolPreview(face, tool, face.ZIndex + 1)
		-- číslo klávesy
		local badge = new("Frame", {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(-6, -6),
			BackgroundColor3 = T.Dark,
			ZIndex = face.ZIndex + 3,
			Parent = holder,
		})
		UIKit.corner(badge, 12)
		UIKit.stroke(badge, 2.5, tier)
		UIKit.text({
			Text = tostring(index),
			Size = UDim2.fromScale(1, 1),
			Font = UIKit.Font.Title,
			Stroke = false,
			ZIndex = face.ZIndex + 4,
			Parent = badge,
		})
		-- zlatý rámeček vybraného slotu
		local ring = new("Frame", {
			Name = "Ring",
			Size = UDim2.new(1, 12, 1, 6),
			Position = UDim2.fromOffset(-6, -6),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = face.ZIndex + 2,
			Parent = holder,
		})
		UIKit.corner(ring, 20)
		local ringStroke = UIKit.stroke(ring, 4, T.Gold)
		-- ukazatel "v ruce"
		local hand = new("Frame", {
			Name = "InHand",
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(28, 8),
			Position = UDim2.new(0.5, 0, 1, 2),
			BackgroundColor3 = T.Green,
			Visible = false,
			ZIndex = face.ZIndex + 2,
			Parent = holder,
		})
		UIKit.corner(hand, 4)
		UIKit.stroke(hand, 2)
		table.insert(slots, {
			ToolId = tool.Id,
			Container = container,
			Holder = holder,
			Face = face,
			Ring = ring,
			RingStroke = ringStroke,
			Hand = hand,
		})
	end

	if nextLocked then
		local container = new("Frame", {
			Name = "LockedSlot",
			Size = UDim2.fromOffset(SLOT, SLOT + 14),
			BackgroundTransparency = 1,
			LayoutOrder = 100,
			Parent = bar,
		})
		local holder, face = UIKit.button({
			Name = "Button",
			Size = UDim2.fromOffset(SLOT, SLOT + 6),
			Position = UDim2.fromOffset(0, 8),
			Color = T.Gray,
			Text = "",
			Radius = 16,
			Parent = container,
			OnClick = function()
				ctx.open("Shop")
			end,
		})
		UIKit.text({
			Text = "🔒",
			Size = UDim2.new(1, 0, 0.55, 0),
			Position = UDim2.fromScale(0, 0.02),
			Stroke = false,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
		UIKit.text({
			Text = "💰 " .. Util.formatNumber(nextLocked.Price),
			Size = UDim2.new(1, 4, 0.34, 0),
			Position = UDim2.new(0, -2, 0.6, 0),
			Font = UIKit.Font.Title,
			Stroke = 2,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
		table.insert(
			slots,
			{ ToolId = nextLocked.Id, Container = container, Holder = holder, Face = face, Locked = true }
		)
	end

	bar.Size = UDim2.fromOffset(#slots * (SLOT + GAP), SLOT + 14)
end

local function refreshHighlight()
	if not state then
		return
	end
	holding = heldTool() ~= nil
	for _, slot in slots do
		if not slot.Locked then
			local selected = slot.ToolId == state.EquippedTool
			slot.Ring.Visible = selected
			slot.Hand.Visible = selected and holding
			slot.RingStroke.Color = if holding then T.Gold else T.White
			slot.Holder.Position = UDim2.fromOffset(0, if selected then 0 else 8)
		end
	end
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

function Hotbar.update(newState)
	state = newState
	local parts = {}
	for _, tool in Config.Tools do
		table.insert(parts, if ownsTool(tool) then "1" else "0")
	end
	local nextSignature = table.concat(parts)
	if nextSignature ~= signature then
		signature = nextSignature
		buildSlots()
	end
	refreshHighlight()
end

function Hotbar.build(parent: Instance, context)
	ctx = context
	bar = new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(SLOT, SLOT + 14),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bar,
	})
	nameLabel = UIKit.text({
		Name = "ToolName",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -206),
		Size = UDim2.fromOffset(500, 40),
		Font = UIKit.Font.Title,
		Stroke = 3,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	nameScale = new("UIScale", { Parent = nameLabel })

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local index = KEYS[input.KeyCode.Name]
		if index and slots[index] and not slots[index].Locked then
			selectTool(slots[index].ToolId)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			cycle(1)
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			cycle(-1)
		end
	end)

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(refreshHighlight)
		character.ChildRemoved:Connect(refreshHighlight)
		refreshHighlight()
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return Hotbar
