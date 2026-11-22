--[[
	MainMenu – úvodní obrazovka: kamera krouží nad Oasis Town a pouští,
	velké logo, tlačítko PLAY (počká, než se poušť vygeneruje), novinky a tipy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local F = UIKit.Font
local new = UIKit.new

local MainMenu = {}

local TIPS = {
	"Deeper chests are rarer – dig down!",
	"Uncover the LOST RUINS for a Mythic relic 💎",
	"Every artifact gives coins forever 📜",
	"Claim your DAILY reward in Oasis Town 🎁",
	"When the desert is 75% gone, a SANDSTORM comes 🌪️",
	"New codes on our TikTok & Instagram 🎟️",
}

local function logoWord(parent: Instance, text: string, y: number, size: number, top: Color3, bottom: Color3)
	local label = UIKit.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(900, size),
		Font = F.Title,
		Stroke = 6,
		ZIndex = 62,
		Parent = parent,
	})
	UIKit.gradient(label, top, bottom)
	-- 3D vytažení (tmavá kopie pod textem)
	local shadow = UIKit.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y + 8),
		Size = UDim2.fromOffset(900, size),
		Font = F.Title,
		TextColor3 = Color3.fromRGB(120, 50, 10),
		Stroke = 6,
		ZIndex = 61,
		Parent = parent,
	})
	return label, shadow
end

function MainMenu.show(gui: ScreenGui, callbacks)
	local camera = workspace.CurrentCamera
	local root = new(
		"Frame",
		{ Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Parent = gui }
	)
	local shade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 20, 5),
		BackgroundTransparency = 0.5,
		ZIndex = 60,
		Parent = root,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.45, 0.95),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
		Rotation = 90,
		Parent = shade,
	})

	-- Všechno v jednom sloupci (logo, podtitul, tlačítka, tip) – nic se nepřekrývá
	-- a sloupec se zmenší, když je obrazovka nízká (mobil).
	local column = new("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 640),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = root,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = column,
	})
	local fit = new("UIScale", { Parent = column })
	local function refit()
		local screenScale = 1
		local guiScale = gui:FindFirstChildOfClass("UIScale")
		if guiScale then
			screenScale = guiScale.Scale
		end
		local available = root.AbsoluteSize and root.AbsoluteSize.Y / math.max(screenScale, 0.01) or 720
		fit.Scale = math.clamp((available - 20) / 640, 0.55, 1)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()

	local logoSlot = new(
		"Frame",
		{ Size = UDim2.fromOffset(900, 250), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 61, Parent = column }
	)
	local logo = new("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(900, 250),
		BackgroundTransparency = 1,
		Rotation = -3,
		ZIndex = 61,
		Parent = logoSlot,
	})
	logoWord(logo, "DUNE", 0, 100, Color3.fromRGB(255, 248, 220), Color3.fromRGB(240, 170, 80))
	logoWord(logo, "DIGGERS", 92, 150, Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 120, 20))
	TweenService:Create(
		logo,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, 8) }
	):Play()
	UIKit.text({
		Text = "Dig up the ENTIRE desert!",
		Size = UDim2.fromOffset(700, 40),
		LayoutOrder = 2,
		Font = F.Body,
		Stroke = 3,
		ZIndex = 62,
		Parent = column,
	})
	local buttons = column
	local finished = false
	local orbit: RBXScriptConnection? = nil
	local playHolder, playFace

	local function play()
		if finished or not workspace:GetAttribute("WorldReady") then
			return
		end
		finished = true
		local fadeFrame = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 225, 160),
			BackgroundTransparency = 1,
			ZIndex = 80,
			Parent = gui,
		})
		local tween = TweenService:Create(fadeFrame, TweenInfo.new(0.35), { BackgroundTransparency = 0 })
		tween:Play()
		tween.Completed:Wait()
		if orbit then
			orbit:Disconnect()
		end
		root:Destroy()
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		callbacks.onPlay()
		TweenService:Create(fadeFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function()
			fadeFrame:Destroy()
		end)
	end

	playHolder, playFace = UIKit.button({
		Size = UDim2.fromOffset(340, 96),
		Color = T.Green,
		Text = "PLAY!",
		LayoutOrder = 3,
		ZIndex = 63,
		Parent = buttons,
		OnClick = play,
	})
	UIKit.button({
		Size = UDim2.fromOffset(300, 64),
		Color = T.Blue,
		Text = "🆕 UPDATES",
		LayoutOrder = 4,
		ZIndex = 63,
		Parent = buttons,
		OnClick = function()
			local panel = root:FindFirstChild("Updates")
			if panel then
				panel.Visible = not panel.Visible
			end
		end,
	})
	local _, musicFace
	local musicHolder
	musicHolder, musicFace = UIKit.button({
		Size = UDim2.fromOffset(300, 64),
		Color = Color3.fromRGB(90, 120, 230),
		Text = "🎵 MUSIC: ON",
		LayoutOrder = 5,
		ZIndex = 63,
		Parent = buttons,
		OnClick = function()
			local on = callbacks.toggleMusic()
			musicFace.Text = if on then "🎵 MUSIC: ON" else "🎵 MUSIC: OFF"
			UIKit.setButtonColor(musicHolder, if on then Color3.fromRGB(90, 120, 230) else T.Gray)
		end,
	})

	-- Novinky
	local updates = new("Frame", {
		Name = "Updates",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.5, 40),
		Size = UDim2.fromOffset(380, 330),
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 64,
		Parent = root,
	})
	UIKit.corner(updates, 22)
	UIKit.stroke(updates, 4)
	UIKit.text({
		Text = "🆕 WHAT'S NEW v" .. Config.Version,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 40),
		TextColor3 = T.Orange,
		Font = F.Title,
		Stroke = 2,
		ZIndex = 65,
		Parent = updates,
	})
	UIKit.text({
		Text = table.concat(Config.Changelog or {}, "\n"),
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 1, -72),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.Text,
		Font = F.Body,
		TextScaled = false,
		TextSize = 22,
		TextWrapped = true,
		Stroke = false,
		ZIndex = 65,
		Parent = updates,
	})

	local tip = UIKit.text({
		Text = "TIP: " .. TIPS[1],
		Size = UDim2.fromOffset(860, 34),
		LayoutOrder = 6,
		Font = F.Body,
		Stroke = 3,
		ZIndex = 62,
		Parent = column,
	})
	UIKit.text({
		Text = "v" .. Config.Version,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(120, 26),
		Font = F.Body,
		Stroke = 2,
		ZIndex = 62,
		Parent = root,
	})
	task.spawn(function()
		local i = 1
		while root.Parent do
			task.wait(4)
			i = i % #TIPS + 1
			tip.Text = "TIP: " .. TIPS[i]
		end
	end)

	-- Stav načítání
	local function updateReady()
		if finished then
			return
		end
		local ready = workspace:GetAttribute("WorldReady") == true
		playFace.Text = if ready then "PLAY!" else "LOADING..."
		UIKit.setButtonColor(playHolder, if ready then T.Green else T.Gray)
	end
	workspace:GetAttributeChangedSignal("WorldReady"):Connect(updateReady)
	updateReady()

	-- Kamera krouží kolem lobby
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		local angle = 0
		local center = Vector3.new(0, Config.World.CampTop + 6, 0)
		orbit = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.06
			local position = center + Vector3.new(math.cos(angle) * 150, 60, math.sin(angle) * 150)
			camera.CFrame = CFrame.lookAt(position, center)
		end)
	end

	return play
end

return MainMenu
