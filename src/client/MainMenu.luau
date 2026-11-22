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

	local logo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(900, 300),
		BackgroundTransparency = 1,
		Rotation = -3,
		ZIndex = 61,
		Parent = root,
	})
	logoWord(logo, "DUNE", 0, 120, Color3.fromRGB(255, 248, 220), Color3.fromRGB(240, 170, 80))
	logoWord(logo, "DIGGERS", 110, 170, Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 120, 20))
	TweenService:Create(
		logo,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0.5, 0, 0, 42) }
	):Play()
	UIKit.text({
		Text = "Dig up the ENTIRE desert!",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 330),
		Size = UDim2.fromOffset(700, 44),
		Font = F.Body,
		Stroke = 3,
		ZIndex = 62,
		Parent = root,
	})

	local buttons = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 400),
		Size = UDim2.fromOffset(360, 260),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = root,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons,
	})

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
		Size = UDim2.fromOffset(340, 100),
		Color = T.Green,
		Text = "PLAY!",
		LayoutOrder = 1,
		ZIndex = 63,
		Parent = buttons,
		OnClick = play,
	})
	UIKit.button({
		Size = UDim2.fromOffset(300, 66),
		Color = T.Blue,
		Text = "🆕 UPDATES",
		LayoutOrder = 2,
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
		Size = UDim2.fromOffset(300, 66),
		Color = Color3.fromRGB(90, 120, 230),
		Text = "🎵 MUSIC: ON",
		LayoutOrder = 3,
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
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(900, 34),
		Font = F.Body,
		Stroke = 3,
		ZIndex = 62,
		Parent = root,
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
