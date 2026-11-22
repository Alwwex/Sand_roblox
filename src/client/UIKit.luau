--[[
	UIKit – stavebnice UI: barvy, písma a hotové prvky (3D tlačítka, panely,
	ikony mincí, lišty, posuvníky). Vzhled odpovídá marketingovým grafikám.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = {}

UIKit.Theme = {
	Panel = Color3.fromRGB(255, 244, 222),
	PanelDark = Color3.fromRGB(244, 224, 188),
	PanelDeep = Color3.fromRGB(226, 196, 150),
	Outline = Color3.fromRGB(61, 29, 8),
	Text = Color3.fromRGB(85, 50, 22),
	SubText = Color3.fromRGB(140, 100, 62),
	White = Color3.new(1, 1, 1),
	Orange = Color3.fromRGB(255, 138, 31),
	Gold = Color3.fromRGB(255, 201, 40),
	Cyan = Color3.fromRGB(71, 220, 255),
	Blue = Color3.fromRGB(61, 155, 255),
	Purple = Color3.fromRGB(169, 85, 255),
	Green = Color3.fromRGB(85, 200, 80),
	Red = Color3.fromRGB(235, 70, 70),
	Pink = Color3.fromRGB(255, 60, 106),
	Gray = Color3.fromRGB(160, 148, 135),
	Sand = Color3.fromRGB(240, 196, 110),
	Dark = Color3.fromRGB(58, 34, 16),
}
local T = UIKit.Theme

UIKit.Font = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
	Small = Enum.Font.GothamMedium,
}

UIKit.clickSound = nil -- nastaví UI (přehraje zvuk kliknutí)

function UIKit.new(className: string, props, children): any
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
local new = UIKit.new

function UIKit.corner(parent: Instance, radius: number)
	return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function UIKit.stroke(parent: Instance, thickness: number, color: Color3?, contextual: boolean?)
	return new("UIStroke", {
		Thickness = thickness,
		Color = color or T.Outline,
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

-- Pozor: UIGradient v Robloxu NÁSOBÍ barvu prvku. Barevný přechod proto
-- používej jen na bílý text/prvek (např. logo). Na barevné plochy je UIKit.shade.
function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent })
end

-- Stínování barevné plochy: nahoře plná barva, dole o "amount" tmavší
function UIKit.shade(parent: Instance, amount: number)
	local bottom = 1 - amount
	return new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom)),
		Rotation = 90,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, px: number, py: number?)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, py or px),
		PaddingBottom = UDim.new(0, py or px),
		Parent = parent,
	})
end

function UIKit.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function UIKit.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Text s obrysem (Stroke = tloušťka obrysu, false = bez obrysu)
function UIKit.text(props): TextLabel
	local strokeThickness = props.Stroke
	local strokeColor = props.StrokeColor
	props.Stroke = nil
	props.StrokeColor = nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or UIKit.Font.Body
	props.TextColor3 = props.TextColor3 or T.White
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local label = new("TextLabel", props)
	if strokeThickness ~= false then
		UIKit.stroke(label, strokeThickness or 2, strokeColor, true)
	end
	return label
end

local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad)

--[[
	3D tlačítko: barevná plocha s přechodem + tmavý "spodek".
	Vrací holder (pro layout) a face (TextButton).
	props: Size, Position, AnchorPoint, Color, Text, Font, TextColor, Icon, OnClick, LayoutOrder, Parent, Radius, Depth
]]
function UIKit.button(props)
	local color = props.Color or T.Orange
	local depth = props.Depth or 5
	local radius = props.Radius or 14
	local holder = new("Frame", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(180, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local base = new("Frame", {
		Name = "Base",
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		BackgroundColor3 = UIKit.darken(color, 0.45),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.corner(base, radius)
	UIKit.stroke(base, 3)
	local face = new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -depth),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = props.Text or "",
		Font = props.Font or UIKit.Font.Title,
		TextColor3 = props.TextColor or T.White,
		TextScaled = true,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.corner(face, radius)
	UIKit.stroke(face, 3)
	UIKit.shade(face, 0.22)
	UIKit.padding(face, 10, 7)
	local textStroke = new(
		"UIStroke",
		{ Thickness = 2, Color = T.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = face }
	)
	textStroke.Name = "TextStroke"
	-- lesk nahoře
	local shine = new("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -12, 0.32, 0),
		Position = UDim2.new(0, 6, 0, 4),
		BackgroundColor3 = T.White,
		BackgroundTransparency = 0.78,
		ZIndex = holder.ZIndex + 1,
		Parent = face,
	})
	UIKit.corner(shine, radius)
	local scale = new("UIScale", { Parent = holder })

	face.MouseEnter:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1.05 }):Play()
	end)
	face.MouseLeave:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, depth - 1) }):Play()
	end)
	face.MouseButton1Up:Connect(function()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
	face.Activated:Connect(function()
		if UIKit.clickSound then
			UIKit.clickSound()
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	return holder, face
end

-- Přebarví 3D tlačítko
function UIKit.setButtonColor(holder: Frame, color: Color3)
	local face = holder:FindFirstChild("Face") :: TextButton?
	local base = holder:FindFirstChild("Base") :: Frame?
	if face then
		face.BackgroundColor3 = color
	end
	if base then
		base.BackgroundColor3 = UIKit.darken(color, 0.45)
	end
end

-- Čtvercové tlačítko menu: velká ikona + popisek + červená tečka (upozornění)
function UIKit.menuButton(props)
	local holder, face = UIKit.button({
		Name = props.Name,
		Size = props.Size or UDim2.fromOffset(76, 80),
		Color = props.Color,
		Text = "",
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Parent = props.Parent,
		Radius = 16,
	})
	UIKit.text({
		Text = props.Icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		Position = UDim2.fromScale(0, -0.06),
		Stroke = false,
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})
	UIKit.text({
		Text = props.Label,
		Size = UDim2.new(1, 4, 0.34, 0),
		Position = UDim2.new(0, -2, 0.66, 0),
		Font = UIKit.Font.Title,
		Stroke = 2,
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})
	local dot = new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -8, 0, -8),
		BackgroundColor3 = T.Red,
		Visible = false,
		ZIndex = face.ZIndex + 3,
		Parent = holder,
	})
	UIKit.corner(dot, 11)
	UIKit.stroke(dot, 3)
	UIKit.text({
		Text = "!",
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Font.Title,
		Stroke = false,
		ZIndex = face.ZIndex + 4,
		Parent = dot,
	})
	return holder, face, dot
end

-- Ikona mince složená z kruhů
function UIKit.coin(parent: Instance, size: number, position: UDim2?, zIndex: number?)
	local z = zIndex or 2
	local coin = new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		BackgroundColor3 = T.Gold,
		ZIndex = z,
		Parent = parent,
	})
	UIKit.corner(coin, size)
	UIKit.stroke(coin, math.max(2, size / 14))
	UIKit.shade(coin, 0.18)
	local inner = new("Frame", {
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.19, 0.19),
		BackgroundColor3 = Color3.fromRGB(255, 220, 90),
		ZIndex = z + 1,
		Parent = coin,
	})
	UIKit.corner(inner, size)
	new("UIStroke", { Thickness = math.max(1, size / 22), Color = Color3.fromRGB(214, 138, 0), Parent = inner })
	local slot = new("Frame", {
		Size = UDim2.fromScale(0.16, 0.42),
		Position = UDim2.fromScale(0.42, 0.29),
		BackgroundColor3 = Color3.fromRGB(214, 138, 0),
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = coin,
	})
	UIKit.corner(slot, 3)
	return coin
end

-- Lišta s výplní a textem
function UIKit.bar(props)
	local background = new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = T.Dark,
		Parent = props.Parent,
	})
	UIKit.corner(background, props.Radius or 12)
	UIKit.stroke(background, 3)
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or T.Sand,
		Parent = background,
	})
	UIKit.corner(fill, props.Radius or 12)
	UIKit.shade(fill, 0.2)
	local shine = new("Frame", {
		Size = UDim2.new(1, -6, 0.3, 0),
		Position = UDim2.new(0, 3, 0, 3),
		BackgroundColor3 = T.White,
		BackgroundTransparency = 0.7,
		Parent = fill,
	})
	UIKit.corner(shine, 8)
	local label = UIKit.text({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		Font = UIKit.Font.Title,
		ZIndex = 3,
		Parent = background,
	})
	return background, fill, label
end

-- Posuvník 0..1 (hlasitost)
function UIKit.slider(props)
	local value = props.Value or 0.5
	local track = new("Frame", {
		Name = "Slider",
		Size = props.Size or UDim2.fromOffset(260, 22),
		Position = props.Position or UDim2.new(),
		BackgroundColor3 = T.PanelDeep,
		Parent = props.Parent,
	})
	UIKit.corner(track, 11)
	UIKit.stroke(track, 3)
	local fill =
		new("Frame", { Size = UDim2.fromScale(value, 1), BackgroundColor3 = props.Color or T.Orange, Parent = track })
	UIKit.corner(fill, 11)
	local knob = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		BackgroundColor3 = T.White,
		ZIndex = 3,
		Parent = track,
	})
	UIKit.corner(knob, 17)
	UIKit.stroke(knob, 3)

	local dragging = false
	local function set(v: number, fire: boolean)
		value = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		if fire and props.OnChanged then
			props.OnChanged(value)
		end
	end
	local function fromInput(input: InputObject)
		local x = input.Position.X
		local abs = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		set((x - abs) / width, true)
	end
	local function begin(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			fromInput(input)
		end
	end
	track.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			fromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	return track, function(v)
		set(v, false)
	end
end

-- Přepínač ON/OFF
function UIKit.toggle(props)
	local on = props.Value == true
	local holder, face
	holder, face = UIKit.button({
		Size = props.Size or UDim2.fromOffset(120, 50),
		Position = props.Position,
		Color = if on then T.Green else T.Gray,
		Text = if on then "ON" else "OFF",
		Parent = props.Parent,
		OnClick = function()
			on = not on
			face.Text = if on then "ON" else "OFF"
			UIKit.setButtonColor(holder, if on then T.Green else T.Gray)
			if props.OnChanged then
				props.OnChanged(on)
			end
		end,
	})
	return holder,
		function(v: boolean)
			on = v
			face.Text = if on then "ON" else "OFF"
			UIKit.setButtonColor(holder, if on then T.Green else T.Gray)
		end
end

function UIKit.pop(instance: Instance, from: number?)
	local scale = instance:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = instance })
	scale.Scale = from or 0.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	return scale
end

return UIKit
