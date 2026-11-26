-- Ambience | Premium Roblox Menu | Single File
-- Menu key: RightShift (rebindable) | Mobile + PC | Delta compatible
-- Tabs: Aimbot, Combat, Teams, ESP, Chams, Tracers, HUD, World, Skybox, Lighting,
--       Movement, Fly, Players, Waypoints, Misc, Colors, Effects, Fonts, Configs,
--       Remote Spy, Game, Settings

local genv = (getgenv and getgenv()) or _G
if genv.AmbienceUnload then pcall(genv.AmbienceUnload) end

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
local function svc(n)
	local s = game:GetService(n)
	local ok, c = pcall(function() return cloneref and cloneref(s) end)
	return (ok and c) or s
end
local Players, RS, UIS, TS = svc("Players"), svc("RunService"), svc("UserInputService"), svc("TweenService")
local Lighting, HttpService, VU, MPS, TPS = svc("Lighting"), svc("HttpService"), svc("VirtualUser"), svc("MarketplaceService"), svc("TeleportService")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local F, UI = {}, {}                       -- flags / ui setters
local conns, Accents = {}, {}
local alive = true
local S = { rows = {}, pages = {}, order = {}, building = nil, lo = 0, tabs = {}, current = nil, mode = "Dark", fxSpeed = 1, fxDensity = 1, menuFont = nil, rainbow = false }
local T = {
	text = Color3.fromRGB(242, 242, 247),
	sub = Color3.fromRGB(150, 152, 165),
	accent = Color3.fromHSV(0.74, 0.45, 1),
	hue = 0.74, sat = 0.45,
}
local Pal = {
	Dark = { text = Color3.fromRGB(242, 242, 247), sub = Color3.fromRGB(150, 152, 165), fill = WHITE, win = Color3.fromRGB(9, 9, 12), side = BLACK, stroke = WHITE },
	Light = { text = Color3.fromRGB(24, 24, 30), sub = Color3.fromRGB(104, 106, 120), fill = BLACK, win = Color3.fromRGB(242, 242, 247), side = WHITE, stroke = BLACK },
}
local SkinKinds = { text = "TextColor3", sub = "TextColor3", fill = "BackgroundColor3", win = "BackgroundColor3", side = "BackgroundColor3", stroke = "Color" }
local Skin = {}

local function skin(o, kind)
	Skin[#Skin + 1] = { o, kind }
	local p = Pal[S.mode][kind]
	if p then pcall(function() o[SkinKinds[kind]] = p end) end
end
local function applyMode(m)
	local real = m
	if m == "System" then
		local h = tonumber(os.date("%H")) or 12
		real = (h >= 19 or h < 7) and "Dark" or "Light"
	end
	S.mode = real
	local p = Pal[real]
	local live = {}
	for _, e in ipairs(Skin) do
		if e[1] and e[1].Parent then
			live[#live + 1] = e
			pcall(function() e[1][SkinKinds[e[2]]] = p[e[2]] end)
		end
	end
	Skin = live
end

local function onAccent(fn) Accents[#Accents + 1] = fn; pcall(fn, T.accent) end
local function setAccent(c) T.accent = c; for _, f in ipairs(Accents) do pcall(f, c) end end
local function conn(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function lo() S.lo += 1; return S.lo end

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function new(class, props, kids)
	local o = Instance.new(class)
	props = props or {}
	for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	local bc, bt = props.BackgroundColor3, props.BackgroundTransparency
	if bc and bt and bt >= 0.5 and bt < 1 then
		if bc == WHITE then skin(o, "fill") elseif bc == BLACK then skin(o, "side") end
	end
	if props.TextColor3 == T.text then skin(o, "text") elseif props.TextColor3 == T.sub then skin(o, "sub") end
	if class == "UIStroke" and props.Color == WHITE and (props.Transparency or 0) >= 0.5 then skin(o, "stroke") end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function rd(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p }) end
local function stroke(p, col, tr, th) return new("UIStroke", { Color = col or WHITE, Transparency = tr or 0.9, Thickness = th or 1, Parent = p }) end
local function tw(o, t, props, style, dir)
	local tween = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tween:Play(); return tween
end
local function label(p, text, size, col, font, xa)
	return new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 13, TextColor3 = col or T.text,
		Font = font or Enum.Font.GothamMedium, TextXAlignment = xa or Enum.TextXAlignment.Left, Parent = p,
	})
end
local function line(fr, p1, p2, th)
	local d = p2 - p1
	fr.AnchorPoint = Vector2.new(0.5, 0.5)
	fr.Position = UDim2.fromOffset((p1.X + p2.X) / 2, (p1.Y + p2.Y) / 2)
	fr.Size = UDim2.fromOffset(d.Magnitude, th or 1.5)
	fr.Rotation = math.deg(math.atan2(d.Y, d.X))
end
local function fmt(v) return tostring(math.floor(v * 100 + 0.5) / 100) end
local function lerp(a, b, t) return a + (b - a) * t end

local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	local ok2, cg = pcall(function() return svc("CoreGui") end)
	if ok2 and cg then return cg end
	return LP:WaitForChild("PlayerGui")
end
local GuiParent = guiParent()

local Orig = {
	light = {}, gravity = workspace.Gravity, fov = Cam.FieldOfView, hum = setmetatable({}, { __mode = "k" }), sky = {},
}
for _, k in ipairs({ "Brightness", "ClockTime", "FogEnd", "FogStart", "FogColor", "GlobalShadows", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do
	Orig.light[k] = Lighting[k]
end

----------------------------------------------------------------------
-- VECTOR-STYLE ICON LIBRARY (drawn from primitives, recolorable)
----------------------------------------------------------------------
local IconDefs = {}
IconDefs.home = function(ring, bar, dot) bar(.33, .36, .5, .09, -38); bar(.67, .36, .5, .09, 38); ring(.5, .68, .6, .42, 3) end
IconDefs.aim = function(ring, bar, dot) ring(.5, .5, .7, .7); dot(.5, .5, .14); bar(.5, .08, .08, .2); bar(.5, .92, .08, .2); bar(.08, .5, .2, .08); bar(.92, .5, .2, .08) end
IconDefs.combat = function(ring, bar, dot) bar(.5, .5, .95, .09, 45); bar(.5, .5, .95, .09, -45); dot(.14, .14, .16); dot(.86, .14, .16) end
IconDefs.teams = function(ring, bar, dot) ring(.32, .3, .26, .26); ring(.68, .3, .26, .26); ring(.32, .78, .42, .32); ring(.68, .78, .42, .32) end
IconDefs.esp = function(ring, bar, dot) ring(.5, .5, .94, .56); dot(.5, .5, .26) end
IconDefs.chams = function(ring, bar, dot) ring(.5, .5, .72, .72, 4); bar(.5, .5, .72, .09, 45); dot(.5, .5, .12) end
IconDefs.tracers = function(ring, bar, dot) dot(.14, .86, .14); bar(.48, .52, .96, .07, -45); ring(.82, .18, .24, .24) end
IconDefs.hud = function(ring, bar, dot) ring(.5, .5, .38, .38); bar(.5, .1, .08, .24); bar(.5, .9, .08, .24); bar(.1, .5, .24, .08); bar(.9, .5, .24, .08) end
IconDefs.players = function(ring, bar, dot) ring(.5, .3, .34, .34); ring(.5, .84, .72, .5) end
IconDefs.move = function(ring, bar, dot) bar(.42, .5, .72, .09); bar(.76, .34, .34, .09, 42); bar(.76, .66, .34, .09, -42) end
IconDefs.fly = function(ring, bar, dot) bar(.5, .56, .09, .82); bar(.38, .24, .34, .09, -45); bar(.62, .24, .34, .09, 45); bar(.32, .86, .22, .08); bar(.68, .86, .22, .08) end
IconDefs.world = function(ring, bar, dot) ring(.5, .5, .88, .88); ring(.5, .5, .4, .88); bar(.5, .5, .88, .07) end
IconDefs.sky = function(ring, bar, dot) ring(.34, .6, .36, .36); ring(.6, .48, .52, .52); bar(.48, .82, .72, .08) end
IconDefs.light = function(ring, bar, dot)
	ring(.5, .5, .38, .38)
	for i = 0, 7 do local a = math.rad(i * 45); dot(.5 + math.cos(a) * .4, .5 + math.sin(a) * .4, .1) end
end
IconDefs.pin = function(ring, bar, dot) ring(.5, .36, .52, .52); dot(.5, .36, .14); bar(.5, .8, .08, .32) end
IconDefs.misc = function(ring, bar, dot) dot(.18, .5, .16); dot(.5, .5, .16); dot(.82, .5, .16) end
IconDefs.palette = function(ring, bar, dot) ring(.5, .5, .88, .88); dot(.36, .36, .13); dot(.64, .34, .13); dot(.72, .6, .13); dot(.4, .66, .13) end
IconDefs.fx = function(ring, bar, dot) bar(.5, .5, .09, .94); bar(.5, .5, .94, .09); bar(.5, .5, .09, .5, 45); bar(.5, .5, .09, .5, -45) end
IconDefs.font = "Aa"
IconDefs.config = function(ring, bar, dot) ring(.5, .6, .9, .56, 3); bar(.28, .22, .3, .1) end
IconDefs.settings = function(ring, bar, dot)
	ring(.5, .5, .5, .5); dot(.5, .5, .12)
	for i = 0, 7 do local a = math.rad(i * 45); dot(.5 + math.cos(a) * .4, .5 + math.sin(a) * .4, .13) end
end
IconDefs.spy = ">_"
IconDefs.game = function(ring, bar, dot) ring(.5, .55, .92, .56, 7); bar(.3, .55, .22, .07); bar(.3, .55, .07, .22); dot(.68, .5, .1); dot(.78, .6, .1) end
IconDefs.close = function(ring, bar, dot) bar(.5, .5, .8, .1, 45); bar(.5, .5, .8, .1, -45) end

local function makeIcon(parent, name, px)
	px = px or 18
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(px, px), Parent = parent })
	local parts = {}
	local def = IconDefs[name]
	if type(def) == "string" then
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = def, Font = Enum.Font.GothamBold, TextSize = px * 0.78, TextColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = c })
		parts[1] = { l, "TextColor3" }
	elseif def then
		local function ring(x, y, w, h, r)
			local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundTransparency = 1, Parent = c })
			new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0), Parent = f })
			parts[#parts + 1] = { new("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = f }), "Color" }
		end
		local function bar(x, y, w, h, rot)
			local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rot or 0, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = c })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
			parts[#parts + 1] = { f, "BackgroundColor3" }
		end
		local function dot(x, y, d) bar(x, y, d, d, 0) end
		def(ring, bar, dot)
	end
	local function setCol(col) for _, p in ipairs(parts) do pcall(function() p[1][p[2]] = col end) end end
	setCol(T.sub)
	return c, setCol
end

----------------------------------------------------------------------
-- EYE LOGO (custom animated mark: used for sidebar + floating opener)
----------------------------------------------------------------------
local Eyes = {}
local function makeEye(parent, size, props)
	local E = {}
	local root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	for k, v in pairs(props or {}) do root[k] = v end
	E.root = root
	E.scale = new("UIScale", { Scale = 1, Parent = root })
	local halo = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1.5, 1.5), ImageTransparency = 0.55, Parent = root })
	local ring = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 0.05, Parent = root })
	E.ring = ring
	rd(ring, 999)
	local rs = new("UIStroke", { Thickness = math.max(1.5, size / 22), Color = WHITE, Parent = ring })
	local rg = new("UIGradient", { Rotation = 0, Parent = rs })
	local eye = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.74, .4), BackgroundColor3 = Color3.fromRGB(236, 236, 244), ClipsDescendants = true, Parent = ring })
	rd(eye, 999)
	local es = new("UIStroke", { Thickness = math.max(1, size / 34), Color = WHITE, Transparency = 0.35, Parent = eye })
	local iris = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(size * .3, size * .3), BackgroundColor3 = WHITE, Parent = eye })
	rd(iris, 999)
	local ig = new("UIGradient", { Rotation = 90, Parent = iris })
	local pupil = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.46, .46), BackgroundColor3 = Color3.fromRGB(8, 8, 12), Parent = iris })
	rd(pupil, 999)
	local spark = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.3, .3), Size = UDim2.fromScale(.2, .2), BackgroundColor3 = WHITE, Parent = iris })
	rd(spark, 999)
	local lid = new("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, 0), Size = UDim2.fromScale(1.1, 0), BackgroundColor3 = Color3.fromRGB(10, 10, 14), BorderSizePixel = 0, ZIndex = 3, Parent = eye })
	for i = -1, 1 do
		local l = new("Frame", { AnchorPoint = Vector2.new(.5, 1), Position = UDim2.fromScale(.5 + i * .17, .3), Size = UDim2.fromOffset(math.max(1.5, size / 28), size * .085), Rotation = i * 24, BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = ring })
		rd(l, 2)
		onAccent(function(c) l.BackgroundColor3 = c end)
	end
	onAccent(function(c)
		halo.ImageColor3 = c
		local h, s, v = c:ToHSV()
		rg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(h, math.max(s - .4, 0), 1)), ColorSequenceKeypoint.new(1, c) })
		ig.Color = ColorSequence.new(Color3.fromHSV(h, math.min(s + .25, 1), 1), Color3.fromHSV((h + .08) % 1, s, .55))
	end)
	local nextBlink, blinkT = os.clock() + 2, nil
	function E.update(t, dt, lookX, lookY)
		rg.Rotation = (t * 70) % 360
		local pulse = 0.46 + 0.05 * math.sin(t * 2.2)
		pupil.Size = UDim2.fromScale(pulse, pulse)
		local mx, my = lookX or math.sin(t * 0.7) * .6, lookY or math.cos(t * 0.5) * .35
		iris.Position = UDim2.fromScale(.5 + math.clamp(mx, -1, 1) * .12, .5 + math.clamp(my, -1, 1) * .09)
		halo.ImageTransparency = 0.5 + 0.12 * math.sin(t * 1.6)
		if not blinkT and t > nextBlink then blinkT = t end
		if blinkT then
			local k = (t - blinkT) / 0.22
			if k >= 1 then blinkT = nil; nextBlink = t + 2 + math.random() * 4; lid.Size = UDim2.fromScale(1.1, 0)
			else lid.Size = UDim2.fromScale(1.1, math.sin(k * math.pi) * 0.56) end
		end
	end
	Eyes[#Eyes + 1] = E
	return E
end

-- Brand logo: your uploaded asset cropped into a circle, with the animated eye as an automatic fallback.
local LOGO_ID = 136881487167739
local function makeLogo(parent, size, props)
	local E = makeEye(parent, size, props)
	E.ring.Visible = false
	local disc = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 14), ZIndex = 5, Parent = E.root })
	rd(disc, 999)
	local st = new("UIStroke", { Thickness = math.max(1.5, size / 24), Color = T.accent, Parent = disc })
	onAccent(function(c) st.Color = c end)
	local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 6, Parent = disc })
	rd(img, 999)
	task.spawn(function()
		for _, src in ipairs({ ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(LOGO_ID), "rbxassetid://" .. LOGO_ID, "rbxassetid://" .. (LOGO_ID - 1) }) do
			img.Image = src
			local t0 = os.clock()
			while os.clock() - t0 < 3.5 and not img.IsLoaded do task.wait(0.1) end
			if img.IsLoaded then return end
		end
		disc.Visible = false; E.ring.Visible = true
	end)
	return E
end

----------------------------------------------------------------------
-- ROOT GUI + WINDOW
----------------------------------------------------------------------
local G = {}
local W0, H0, SB, PW = 760, 460, 172, 204
G.Gui = new("ScreenGui", { Name = "Ambience", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = GuiParent })
G.Holder = new("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W0, H0), BackgroundTransparency = 1, Parent = G.Gui })
G.UIs = new("UIScale", { Scale = 1, Parent = G.Holder })
G.Halo = new("ImageLabel", {
	BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276),
	Position = UDim2.fromOffset(-30, -30), Size = UDim2.new(1, 60, 1, 60), ImageTransparency = 0.74, Parent = G.Holder,
})
onAccent(function(c) G.Halo.ImageColor3 = c end)
G.Win = new("CanvasGroup", { Name = "Win", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Pal.Dark.win, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = G.Holder })
skin(G.Win, "win"); rd(G.Win, 22)
G.Edge = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = G.Holder }); rd(G.Edge, 22)
stroke(G.Edge, WHITE, 0.8, 1)
G.Sheen = new("Frame", { Size = UDim2.fromScale(1, 0.55), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, BorderSizePixel = 0, ZIndex = 0, Parent = G.Win })
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = G.Sheen })
G.FXRoot = new("Frame", { Name = "FX", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1, Parent = G.Win })
G.blur = new("BlurEffect", { Name = "AmbienceBlur", Size = 0, Parent = Lighting })
G.baseScale, G.isOpen = 1, false

local function autoScale()
	local vp = Cam.ViewportSize
	local base = math.clamp(math.min(vp.X / (W0 + 60), vp.Y / (H0 + 40)), 0.42, 1.1)
	G.baseScale = base * (F.uiscale or 1) * (F.compact and 0.84 or 1)
	if G.UIs then G.UIs.Scale = G.baseScale end
end
autoScale()
conn(Cam:GetPropertyChangedSignal("ViewportSize"), autoScale)

local function drag(handle, target)
	local dragging, start, startPos
	conn(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, start, startPos = true, i.Position, target.Position
		end
	end)
	conn(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	conn(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

----------------------------------------------------------------------
-- BACKGROUND FX ENGINE (15 animated backgrounds)
----------------------------------------------------------------------
local FX, fxUpdate, fxName = {}, nil, "Off"
local function D(n) return math.max(2, math.floor(n * S.fxDensity + 0.5)) end
local function clearFX() for _, c in ipairs(G.FXRoot:GetChildren()) do c:Destroy() end fxUpdate = nil end
local function fxDot(sz, tr, col)
	local f = new("Frame", { Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = col or WHITE, BackgroundTransparency = tr or 0.5, BorderSizePixel = 0, Parent = G.FXRoot })
	rd(f, sz); return f
end
local function blob(col, size)
	return new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276), AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(size, size), ImageColor3 = col, ImageTransparency = 0.6, Parent = G.FXRoot })
end

FX.Stars = function()
	local p = {}
	for i = 1, D(70) do p[i] = { fxDot(math.random(1, 3)), math.random(), math.random(), math.random() * 0.01 + 0.003, math.random() * 6 } end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[2] = (o[2] + o[4] * dt) % 1
			o[1].Position = UDim2.fromScale(o[2], o[3])
			o[1].BackgroundTransparency = 0.35 + 0.55 * math.abs(math.sin(t * 1.1 + o[5]))
		end
	end
end
FX.Snow = function()
	local p = {}
	for i = 1, D(55) do p[i] = { fxDot(math.random(2, 4), 0.3), math.random(), math.random(), math.random() * 0.06 + 0.03, math.random() * 6 } end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] = (o[3] + o[4] * dt) % 1
			o[1].Position = UDim2.fromScale((o[2] + math.sin(t * 0.6 + o[5]) * 0.015) % 1, o[3])
		end
	end
end
FX.Sakura = function()
	local p = {}
	for i = 1, D(28) do
		local f = new("Frame", { Size = UDim2.fromOffset(math.random(8, 12), math.random(5, 8)), BackgroundColor3 = Color3.fromRGB(255, 178, 208), BackgroundTransparency = math.random() * 0.3 + 0.05, BorderSizePixel = 0, Parent = G.FXRoot })
		rd(f, 6)
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 205, 225), Color3.fromRGB(255, 140, 185)), Rotation = 45, Parent = f })
		p[i] = { f, math.random(), math.random(), math.random() * 0.05 + 0.04, math.random() * 6, math.random() * 60 + 30 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] += o[4] * dt
			if o[3] > 1.06 then o[3] = -0.06; o[2] = math.random() end
			o[1].Position = UDim2.fromScale((o[2] + math.sin(t * 0.7 + o[5]) * 0.05) % 1, o[3])
			o[1].Rotation = t * o[6] + o[5] * 50
		end
	end
end
FX.Topographic = function()
	local rings = {}
	local centers = { { 0.3, 0.38 }, { 0.78, 0.72 }, { 0.62, 0.16 } }
	for ci, c in ipairs(centers) do
		for i = 1, D(11) do
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = G.FXRoot }); rd(f, 9999)
			local s = new("UIStroke", { Thickness = 1, Color = T.accent, Transparency = 0.7, Parent = f })
			rings[#rings + 1] = { f, s, c, i, ci }
		end
	end
	local n = D(11)
	return function(t)
		for _, r in ipairs(rings) do
			local f, s, c, i, ci = r[1], r[2], r[3], r[4], r[5]
			local k = i * (330 / n) + math.sin(t * 0.4 + i * 0.7 + ci) * 9
			f.Size = UDim2.fromOffset(k * 1.9 + math.sin(t * 0.3 + i) * 20, k * 1.25 + math.cos(t * 0.33 + i) * 14)
			f.Position = UDim2.new(c[1], math.sin(t * 0.15 + ci) * 22, c[2], math.cos(t * 0.12 + ci) * 18)
			f.Rotation = 24 * ci + math.sin(t * 0.2 + i * 0.3) * 14
			s.Color = T.accent
			s.Transparency = 0.55 + 0.4 * (i / n)
		end
	end
end
FX.Aurora = function()
	local bands = {}
	local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.5), NumberSequenceKeypoint.new(1, 1) })
	local N = D(22)
	for i = 1, N do
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, math.random(2, 5), 0.9, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = G.FXRoot })
		new("UIGradient", { Rotation = 90, Transparency = seq, Parent = f })
		bands[i] = { f, i, math.random() * 6 }
	end
	local rib = {}
	for i = 1, 3 do
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.35, 0, 0.7, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = G.FXRoot })
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) }), Parent = f })
		rib[i] = f
	end
	return function(t)
		for _, b in ipairs(bands) do
			local f, i, ph = b[1], b[2], b[3]
			f.Position = UDim2.fromScale(i / (N + 1) + math.sin(t * 0.22 + ph) * 0.04, 0.02 + 0.05 * math.sin(t * 0.3 + i))
			f.Rotation = math.sin(t * 0.3 + i * 0.5) * 12
			f.Size = UDim2.new(0, f.Size.X.Offset, 0.55 + 0.3 * math.sin(t * 0.4 + ph), 0)
			f.BackgroundColor3 = Color3.fromHSV(0.33 + 0.27 * (0.5 + 0.5 * math.sin(t * 0.2 + i * 0.35)), 0.7, 1)
		end
		for i, f in ipairs(rib) do
			f.Position = UDim2.fromScale(0.2 + 0.3 * i + math.sin(t * 0.12 + i) * 0.05, 0)
			f.BackgroundColor3 = Color3.fromHSV((0.4 + 0.2 * i + t * 0.03) % 1, 0.6, 1)
		end
	end
end
FX.Waves = function()
	local segs, N = {}, 34
	for l = 1, 3 do
		for i = 1, N do
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W0 / N + 4, 2), BackgroundColor3 = T.accent, BackgroundTransparency = 0.45 + l * 0.12, BorderSizePixel = 0, Parent = G.FXRoot })
			segs[#segs + 1] = { f, l, i }
		end
	end
	return function(t)
		for _, s in ipairs(segs) do
			local f, l, i = s[1], s[2], s[3]
			local x = i / N
			local a = x * 7 + t * (0.6 + l * 0.2)
			f.Position = UDim2.fromScale(x, 0.55 + l * 0.11 + math.sin(a) * 0.045)
			f.Rotation = math.deg(math.atan(math.cos(a) * 0.045 * 7 * H0 / W0))
			f.BackgroundColor3 = T.accent
		end
	end
end
FX.Grid = function()
	local v, h = {}, {}
	for i = 1, 14 do v[i] = new("Frame", { Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.accent, BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = G.FXRoot }) end
	for i = 1, 9 do h[i] = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.accent, BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = G.FXRoot }) end
	return function(t)
		for i, f in ipairs(v) do f.Position = UDim2.fromScale(((i / 14) + t * 0.01) % 1, 0); f.BackgroundColor3 = T.accent end
		for i, f in ipairs(h) do f.Position = UDim2.fromScale(0, ((i / 9) + t * 0.02) % 1); f.BackgroundColor3 = T.accent end
	end
end
FX.Pulse = function()
	local r = {}
	for i = 1, 4 do
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.5), BackgroundTransparency = 1, Parent = G.FXRoot }); rd(f, 9999)
		r[i] = { f, stroke(f, T.accent, 0.5, 2) }
	end
	return function(t)
		for i, o in ipairs(r) do
			local k = ((t * 0.18) + i / 4) % 1
			o[1].Size = UDim2.fromOffset(k * 640, k * 640)
			o[2].Transparency = 0.45 + 0.55 * k
			o[2].Color = T.accent
		end
	end
end
FX.Matrix = function()
	local cols, N, chars = {}, D(22), "01ABCDEFXYZ#$%&"
	for i = 1, N do
		local c = { x = (i - 0.5) / N, y = math.random(), sp = math.random() * 0.25 + 0.12, labels = {} }
		for k = 1, 7 do
			c.labels[k] = new("TextLabel", { BackgroundTransparency = 1, Text = "0", Font = Enum.Font.Code, TextSize = 12, TextColor3 = T.accent, Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0), Parent = G.FXRoot })
		end
		cols[i] = c
	end
	local acc = 0
	return function(t, dt)
		acc += dt
		local swap = acc > 0.12; if swap then acc = 0 end
		for _, c in ipairs(cols) do
			c.y += c.sp * dt; if c.y > 1.2 then c.y = -0.1 end
			for k, l in ipairs(c.labels) do
				l.Position = UDim2.new(c.x, 0, c.y, -(k - 1) * 13)
				l.TextTransparency = 0.3 + k * 0.1
				l.TextColor3 = T.accent
				if swap and math.random() < 0.4 then local r = math.random(1, #chars); l.Text = chars:sub(r, r) end
			end
		end
	end
end
FX.Fireflies = function()
	local p = {}
	for i = 1, D(18) do
		local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(255, 236, 150), BorderSizePixel = 0, Parent = G.FXRoot }); rd(f, 4)
		local h = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(28, 28), ImageColor3 = Color3.fromRGB(255, 230, 120), Parent = f })
		p[i] = { f, h, math.random(), math.random(), math.random() * 6, math.random() * 0.3 + 0.1 }
	end
	return function(t)
		for _, o in ipairs(p) do
			o[1].Position = UDim2.fromScale(o[3] + math.sin(t * o[6] + o[5]) * 0.06, o[4] + math.cos(t * o[6] * 0.8 + o[5]) * 0.06)
			local a = 0.5 + 0.5 * math.sin(t * 1.5 + o[5])
			o[1].BackgroundTransparency = 1 - a * 0.9; o[2].ImageTransparency = 1 - a * 0.5
		end
	end
end
FX.Rain = function()
	local p = {}
	for i = 1, D(45) do
		local f = new("Frame", { Size = UDim2.fromOffset(1, math.random(10, 18)), Rotation = 12, BackgroundColor3 = Color3.fromRGB(190, 215, 255), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = G.FXRoot })
		p[i] = { f, math.random(), math.random(), math.random() * 0.5 + 0.6 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] += o[4] * dt; o[2] -= 0.12 * dt
			if o[3] > 1.05 then o[3] = -0.05; o[2] = math.random() end
			o[1].Position = UDim2.fromScale(o[2] % 1, o[3])
		end
	end
end
FX.Embers = function()
	local p = {}
	for i = 1, D(34) do
		local f = fxDot(math.random(2, 4), 0.2, Color3.fromRGB(255, math.random(110, 170), 60))
		p[i] = { f, math.random(), math.random(), math.random() * 0.08 + 0.04, math.random() * 6 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] -= o[4] * dt
			if o[3] < -0.05 then o[3] = 1.05; o[2] = math.random() end
			o[1].Position = UDim2.fromScale((o[2] + math.sin(t + o[5]) * 0.03) % 1, o[3])
			o[1].BackgroundTransparency = 0.25 + 0.5 * math.abs(math.sin(t * 3 + o[5]))
		end
	end
end
FX.Bubbles = function()
	local p = {}
	for i = 1, D(16) do
		local sz = math.random(14, 46)
		local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(sz, sz), BackgroundTransparency = 1, Parent = G.FXRoot }); rd(f, 999)
		local s = stroke(f, T.accent, 0.55, 1.2)
		p[i] = { f, s, math.random(), math.random(), math.random() * 0.06 + 0.03, math.random() * 6 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[4] -= o[5] * dt
			if o[4] < -0.08 then o[4] = 1.08; o[3] = math.random() end
			o[1].Position = UDim2.fromScale((o[3] + math.sin(t * 0.8 + o[6]) * 0.02) % 1, o[4])
			o[2].Color = T.accent
		end
	end
end
FX.Warp = function()
	local p = {}
	for i = 1, D(55) do
		local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = G.FXRoot })
		p[i] = { f, math.random() * math.pi * 2, math.random(), math.random() * 0.3 + 0.25 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] += o[4] * dt * (0.4 + o[3] * 1.6)
			if o[3] > 1 then o[3] = 0.02; o[2] = math.random() * math.pi * 2 end
			local R = o[3] * 480
			o[1].Position = UDim2.new(0.62, math.cos(o[2]) * R, 0.5, math.sin(o[2]) * R)
			o[1].Size = UDim2.fromOffset(2 + o[3] * 26, 1.4)
			o[1].Rotation = math.deg(o[2])
			o[1].BackgroundTransparency = 1 - o[3] * 0.85
		end
	end
end
FX.Orbs = function()
	local p = {}
	for i = 1, 5 do p[i] = { blob(T.accent, math.random(200, 320)), math.random(), math.random(), math.random() * 6 } end
	return function(t)
		for i, o in ipairs(p) do
			o[1].Position = UDim2.fromScale(o[2] + math.sin(t * 0.13 + o[4]) * 0.22, o[3] + math.cos(t * 0.11 + o[4]) * 0.22)
			local h, s = T.accent:ToHSV()
			o[1].ImageColor3 = Color3.fromHSV((h + i * 0.07 + math.sin(t * 0.1 + i) * 0.05) % 1, math.max(s, 0.5), 1)
			o[1].ImageTransparency = 0.62 + 0.1 * math.sin(t * 0.5 + i)
		end
	end
end
FX.Constellation = function()
	local pts, lines = {}, {}
	local N = D(20)
	for i = 1, N do pts[i] = { fxDot(3, 0.2), math.random(), math.random(), (math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03 } end
	for i = 1, N * 2 do lines[i] = new("Frame", { BackgroundColor3 = T.accent, BorderSizePixel = 0, Visible = false, Parent = G.FXRoot }) end
	return function(t, dt)
		for _, p in ipairs(pts) do
			p[2] = (p[2] + p[4] * dt) % 1; p[3] = (p[3] + p[5] * dt) % 1
			p[1].Position = UDim2.fromScale(p[2], p[3])
		end
		local n = 0
		for i = 1, #pts do
			for j = i + 1, #pts do
				if n < #lines then
					local a, b = pts[i], pts[j]
					local ax, ay, bx, by = a[2] * W0, a[3] * H0, b[2] * W0, b[3] * H0
					local d = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
					if d < 140 then
						n += 1; local l = lines[n]
						l.Visible = true; line(l, Vector2.new(ax, ay), Vector2.new(bx, by), 1)
						l.BackgroundTransparency = 0.5 + 0.45 * (d / 140); l.BackgroundColor3 = T.accent
					end
				end
			end
		end
		for k = n + 1, #lines do lines[k].Visible = false end
	end
end
FX.Confetti = function()
	local p = {}
	for i = 1, D(34) do
		local f = new("Frame", { Size = UDim2.fromOffset(math.random(4, 8), math.random(3, 5)), BackgroundColor3 = Color3.fromHSV(math.random(), 0.65, 1), BorderSizePixel = 0, Parent = G.FXRoot })
		p[i] = { f, math.random(), math.random(), math.random() * 0.1 + 0.06, math.random() * 6, math.random() * 200 + 80 }
	end
	return function(t, dt)
		for _, o in ipairs(p) do
			o[3] += o[4] * dt
			if o[3] > 1.05 then o[3] = -0.05; o[2] = math.random() end
			o[1].Position = UDim2.fromScale((o[2] + math.sin(t * 1.2 + o[5]) * 0.03) % 1, o[3])
			o[1].Rotation = t * o[6]
		end
	end
end
local FXList = { "Off", "Stars", "Snow", "Sakura", "Topographic", "Aurora", "Waves", "Grid", "Pulse", "Matrix", "Fireflies", "Rain", "Embers", "Bubbles", "Warp", "Orbs", "Constellation", "Confetti" }
local function setFX(name)
	clearFX(); fxName = name
	if FX[name] then local ok, u = pcall(FX[name]); if ok then fxUpdate = u end end
end

----------------------------------------------------------------------
-- SIDEBAR + MAIN FRAMES
----------------------------------------------------------------------
G.Side = new("Frame", { Name = "Side", Size = UDim2.new(0, SB, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = G.Win })
new("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = G.Side })
G.SideDrag = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = G.Side })
drag(G.SideDrag, G.Holder)

-- traffic lights (close / minimize / compact)
G.Lights = {}
for i, d in ipairs({ { Color3.fromRGB(255, 95, 87), "×" }, { Color3.fromRGB(254, 188, 46), "–" }, { Color3.fromRGB(40, 200, 64), "+" } }) do
	local b = new("TextButton", { Text = "", BackgroundColor3 = d[1], Position = UDim2.fromOffset(14 + (i - 1) * 18, 12), Size = UDim2.fromOffset(12, 12), AutoButtonColor = false, Parent = G.Side }); rd(b, 6)
	local g = new("TextLabel", { BackgroundTransparency = 1, Text = d[2], Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(60, 30, 20), TextTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = b })
	conn(b.MouseEnter, function() for _, l in ipairs(G.Lights) do tw(l[2], 0.12, { TextTransparency = 0.1 }) end end)
	conn(b.MouseLeave, function() for _, l in ipairs(G.Lights) do tw(l[2], 0.12, { TextTransparency = 1 }) end end)
	G.Lights[i] = { b, g }
end

G.LogoEye = makeLogo(G.Side, 30, { Position = UDim2.fromOffset(14, 32) })
G.Logo = label(G.Side, "ambience", 17, T.text, Enum.Font.GothamBold); G.Logo.Position = UDim2.fromOffset(52, 31); G.Logo.Size = UDim2.fromOffset(112, 30)
G.LogoSub = label(G.Side, "premium", 9, T.sub, Enum.Font.GothamMedium); G.LogoSub.Position = UDim2.fromOffset(53, 50); G.LogoSub.Size = UDim2.fromOffset(80, 10)

G.SSearch = new("TextBox", {
	PlaceholderText = "Search", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium,
	TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94,
	Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = G.Side,
}); rd(G.SSearch, 9); stroke(G.SSearch, WHITE, 0.92); new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = G.SSearch })

G.TabList = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 106), Size = UDim2.new(1, -16, 1, -166), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), Parent = G.Side })
G.Pill = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Parent = G.TabList }); rd(G.Pill, 10)
G.PillBar = new("Frame", { Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = T.accent, Parent = G.Pill }); rd(G.PillBar, 2)
onAccent(function(c) G.PillBar.BackgroundColor3 = c end)

G.Account = new("Frame", { Position = UDim2.new(0, 10, 1, -52), Size = UDim2.new(1, -20, 0, 42), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Parent = G.Side }); rd(G.Account, 12); stroke(G.Account, WHITE, 0.93)
G.Avatar = new("ImageLabel", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(30, 30, 36), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(LP.UserId), Parent = G.Account }); rd(G.Avatar, 15)
G.AccName = label(G.Account, "Account", 12, T.text, Enum.Font.GothamMedium); G.AccName.Position = UDim2.fromOffset(44, 5); G.AccName.Size = UDim2.new(1, -50, 0, 16)
G.AccSub = label(G.Account, "@" .. LP.Name, 10, T.sub, Enum.Font.Gotham); G.AccSub.Position = UDim2.fromOffset(44, 21); G.AccSub.Size = UDim2.new(1, -50, 0, 14); G.AccSub.TextTruncate = Enum.TextTruncate.AtEnd

G.Main = new("Frame", { Name = "Main", Position = UDim2.fromOffset(SB, 0), Size = UDim2.new(1, -SB, 1, 0), BackgroundTransparency = 1, Parent = G.Win })
G.DragBar = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, ZIndex = 0, Parent = G.Main })
drag(G.DragBar, G.Holder)
G.Title = label(G.Main, "Home", 20, T.text, Enum.Font.GothamBold); G.Title.Position = UDim2.fromOffset(18, 10); G.Title.Size = UDim2.new(0.5, 0, 0, 26)
G.Crumb = label(G.Main, "", 10, T.sub, Enum.Font.Gotham); G.Crumb.Position = UDim2.fromOffset(19, 35); G.Crumb.Size = UDim2.new(0.5, 0, 0, 12)
G.FSearch = new("TextBox", {
	PlaceholderText = "Search features…", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium,
	TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -84, 0, 12), Size = UDim2.fromOffset(160, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = G.Main,
}); rd(G.FSearch, 9); stroke(G.FSearch, WHITE, 0.92); new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = G.FSearch })

----------------------------------------------------------------------
-- TOASTS + CONFIRM
----------------------------------------------------------------------
G.Toast = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, SB / 2, 1, 40), Size = UDim2.fromOffset(240, 34), BackgroundColor3 = Color3.fromRGB(16, 16, 22), BackgroundTransparency = 0.05, ZIndex = 50, Parent = G.Win }); rd(G.Toast, 17)
local toastStroke = stroke(G.Toast, T.accent, 0.3, 1.2); onAccent(function(c) toastStroke.Color = c end)
G.ToastL = label(G.Toast, "", 12, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Center); G.ToastL.Size = UDim2.fromScale(1, 1); G.ToastL.ZIndex = 51
local toastId = 0
local function notify(msg)
	if F.toasts == false then return end
	toastId += 1; local id = toastId
	G.ToastL.Text = msg
	G.Toast.Size = UDim2.fromOffset(math.clamp(#msg * 7.4 + 36, 120, 380), 34)
	tw(G.Toast, 0.45, { Position = UDim2.new(0.5, SB / 2, 1, -16) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if id == toastId and alive then tw(G.Toast, 0.35, { Position = UDim2.new(0.5, SB / 2, 1, 40) }) end
	end)
end

G.Confirm = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Active = true, Visible = false, ZIndex = 80, Parent = G.Win })
G.ConfirmCard = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(280, 130), BackgroundColor3 = Color3.fromRGB(18, 18, 24), ZIndex = 81, Parent = G.Confirm }); rd(G.ConfirmCard, 18); stroke(G.ConfirmCard, WHITE, 0.82)
G.ConfirmT = label(G.ConfirmCard, "Unload Ambience?", 16, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Center); G.ConfirmT.Position = UDim2.fromOffset(0, 16); G.ConfirmT.Size = UDim2.new(1, 0, 0, 22); G.ConfirmT.ZIndex = 82
G.ConfirmS = label(G.ConfirmCard, "Everything gets restored and the menu is removed.", 11, Color3.fromRGB(160, 162, 175), Enum.Font.Gotham, Enum.TextXAlignment.Center); G.ConfirmS.Position = UDim2.fromOffset(14, 42); G.ConfirmS.Size = UDim2.new(1, -28, 0, 30); G.ConfirmS.TextWrapped = true; G.ConfirmS.ZIndex = 82
local confirmCb
local function confirmBtn(txt, x, accent)
	local b = new("TextButton", { Text = txt, TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = WHITE, BackgroundColor3 = accent and Color3.fromRGB(235, 80, 80) or Color3.fromRGB(44, 44, 54), Position = UDim2.new(0.5, x, 1, -18), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(110, 32), AutoButtonColor = false, ZIndex = 82, Parent = G.ConfirmCard }); rd(b, 10)
	return b
end
local cYes, cNo = confirmBtn("Unload", 60, true), confirmBtn("Cancel", -60, false)
conn(cNo.Activated, function() G.Confirm.Visible = false end)
conn(cYes.Activated, function() G.Confirm.Visible = false; if confirmCb then confirmCb() end end)
local function confirm(title, sub, cb)
	G.ConfirmT.Text, G.ConfirmS.Text, confirmCb = title, sub, cb
	G.Confirm.Visible = true
end

----------------------------------------------------------------------
-- OPEN / CLOSE + FLOATING EYE
----------------------------------------------------------------------
G.Float = new("Frame", { Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.fromOffset(54, 54), BackgroundTransparency = 1, Visible = false, Parent = G.Gui })
G.FloatEye = makeLogo(G.Float, 54)
G.FloatBtn = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = G.Float })

local function setOpen(v)
	G.isOpen = v
	if v then
		G.Holder.Visible = true; G.Float.Visible = false
		G.UIs.Scale = G.baseScale * 0.9; G.Win.GroupTransparency = 1; G.Halo.ImageTransparency = 1
		tw(G.UIs, 0.55, { Scale = G.baseScale }, Enum.EasingStyle.Back)
		tw(G.Win, 0.35, { GroupTransparency = 0 }); tw(G.Halo, 0.5, { ImageTransparency = 0.74 })
		if F.blur then tw(G.blur, 0.4, { Size = F.blur_amt or 8 }) end
	else
		tw(G.UIs, 0.3, { Scale = G.baseScale * 0.92 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(G.Win, 0.25, { GroupTransparency = 1 }); tw(G.Halo, 0.25, { ImageTransparency = 1 }); tw(G.blur, 0.3, { Size = 0 })
		task.delay(0.3, function()
			if alive and not G.isOpen then G.Holder.Visible = false; G.Float.Visible = true; G.FloatEye.scale.Scale = 0; tw(G.FloatEye.scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back) end
		end)
	end
end

do -- floating eye: drag vs click
	local moved, sp, st
	conn(G.FloatBtn.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then moved, sp, st = false, i.Position, G.Float.Position end
	end)
	conn(UIS.InputChanged, function(i)
		if sp and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - sp
			if d.Magnitude > 6 then moved = true end
			if moved then G.Float.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y) end
		end
	end)
	conn(UIS.InputEnded, function(i)
		if sp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			if not moved then setOpen(true) end
			sp = nil
		end
	end)
end

conn(G.Lights[1][1].Activated, function() confirm("Unload Ambience?", "Everything gets restored and the menu is removed.", function() if genv.AmbienceUnload then genv.AmbienceUnload() end end) end)
conn(G.Lights[2][1].Activated, function() setOpen(false) end)
conn(G.Lights[3][1].Activated, function()
	if UI.compact then UI.compact(not F.compact) else F.compact = not F.compact; autoScale() end
	notify(F.compact and "Compact mode" or "Full size")
end)

-- classic minimize / close buttons (top-right)
do
	local function winBtn(txt, xoff, cb)
		local b = new("TextButton", { Text = txt, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xoff, 0, 12), Size = UDim2.fromOffset(30, 30), AutoButtonColor = false, Parent = G.Main }); rd(b, 15)
		conn(b.MouseEnter, function() tw(b, 0.15, { BackgroundTransparency = 0.82 }) end)
		conn(b.MouseLeave, function() tw(b, 0.15, { BackgroundTransparency = 0.94 }) end)
		conn(b.Activated, cb)
		return b
	end
	winBtn("–", -48, function() setOpen(false) end)
	local x = winBtn("×", -14, function() confirm("Unload Ambience?", "Everything gets restored and the menu is removed.", function() if genv.AmbienceUnload then genv.AmbienceUnload() end end) end)
	conn(x.MouseEnter, function() x.TextColor3 = Color3.fromRGB(255, 110, 110) end)
	conn(x.MouseLeave, function() x.TextColor3 = Pal[S.mode].sub end)
end
G.AccName.Text = "Avatar Studio"
G.AccBtn = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = G.Account })
local accArrow = label(G.Account, "›", 18, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Right); accArrow.Size = UDim2.new(1, -10, 1, 0)

----------------------------------------------------------------------
-- UI COMPONENT LIBRARY  (newPage, row, sec, tog, sld, btn, opt, bind, chips, colr, cards, info)
----------------------------------------------------------------------
local PVState = { on = false }   -- filled by preview module
local function pageW() return UDim2.new(1, PVState.on and -(PW + 34) or -24, 1, -64) end

local function newPage(name, crumb)
	local sf = new("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = pageW(), Position = UDim2.fromOffset(12, 56),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE, Visible = false, Parent = G.Main,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
	new("UIPadding", { PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), Parent = sf })
	S.pages[name], S.rows[name], S.crumb = sf, {}, S.crumb or {}
	S.crumb[name] = crumb or ""
	S.order[#S.order + 1] = name
	S.building = name
	return sf
end

local function row(parent, name, h)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, h or 38), BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, LayoutOrder = lo(), Parent = parent })
	rd(r, 10); stroke(r, WHITE, 0.93)
	local l = label(r, name, 13, T.text); l.Position = UDim2.fromOffset(12, 0); l.Size = UDim2.new(0.6, 0, 0, 38)
	conn(r.MouseEnter, function() tw(r, 0.15, { BackgroundTransparency = 0.91 }) end)
	conn(r.MouseLeave, function() tw(r, 0.15, { BackgroundTransparency = 0.95 }) end)
	if S.building then table.insert(S.rows[S.building], { r, name:lower() }) end
	return r, l
end

local function sec(parent, title)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = parent })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local head = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = holder })
	local t = label(head, title:upper(), 10, T.sub, Enum.Font.GothamBold); t.Position = UDim2.fromOffset(4, 0); t.Size = UDim2.new(1, -30, 1, 0)
	local ar = label(head, "▾", 12, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Right); ar.Size = UDim2.new(1, -4, 1, 0)
	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = holder })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local open = true
	conn(head.Activated, function() open = not open; body.Visible = open; ar.Text = open and "▾" or "▸" end)
	return body
end

local Hooks = { change = {} }          -- Hooks.change[flag] = {fn,...}: lets other modules react to flag changes
local function fire(flag) for _, fn in ipairs(Hooks.change[flag] or {}) do pcall(fn, F[flag]) end end
local function watch(flag, fn) Hooks.change[flag] = Hooks.change[flag] or {}; table.insert(Hooks.change[flag], fn) end

local function tog(parent, name, flag, default, cb)
	F[flag] = default and true or false
	local r = row(parent, name)
	local pill = new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = Color3.fromRGB(72, 72, 80), AutoButtonColor = false, Parent = r }); rd(pill, 11)
	local knob = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = WHITE, Parent = pill }); rd(knob, 9)
	local function paint(anim)
		local on = F[flag]
		local col = on and T.accent or Color3.fromRGB(72, 72, 80)
		local pos = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		if anim then tw(pill, 0.25, { BackgroundColor3 = col }); tw(knob, 0.4, { Position = pos, Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back)
		else pill.BackgroundColor3 = col; knob.Position = pos end
	end
	paint(false); onAccent(function() paint(false) end)
	UI[flag] = function(v)
		F[flag] = v and true or false; paint(true)
		if cb then pcall(cb, F[flag]) end
		fire(flag)
	end
	conn(pill.Activated, function() UI[flag](not F[flag]) end)
	if default and cb then task.defer(function() pcall(cb, true) end) end
	return r
end

local function sld(parent, name, flag, min, max, default, step, cb, suffix)
	F[flag] = default
	local r = row(parent, name, 54)
	local val = label(r, fmt(default) .. (suffix or ""), 12, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Right); val.AnchorPoint = Vector2.new(1, 0); val.Position = UDim2.new(1, -12, 0, 0); val.Size = UDim2.fromOffset(80, 30)
	local track = new("Frame", { Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = Color3.fromRGB(70, 70, 78), BorderSizePixel = 0, Parent = r }); rd(track, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = track }); rd(fill, 3)
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, Parent = track }); rd(knob, 7)
	onAccent(function(c) fill.BackgroundColor3 = c end)
	local function show(v)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1); knob.Position = UDim2.fromScale(a, 0.5); val.Text = fmt(v) .. (suffix or "")
	end
	show(default)
	local function set(v)
		v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
		F[flag] = v; show(v); if cb then pcall(cb, v) end; fire(flag)
	end
	UI[flag] = set
	local dragging = false
	local scroller = parent:FindFirstAncestorOfClass("ScrollingFrame")
	local function fromX(x) set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)) end
	conn(r.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			local y = i.Position.Y - r.AbsolutePosition.Y
			if y > 22 * G.UIs.Scale then dragging = true; if scroller then scroller.ScrollingEnabled = false end; fromX(i.Position.X) end
		end
	end)
	conn(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end)
	conn(UIS.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false; if scroller then scroller.ScrollingEnabled = true end
		end
	end)
	return r
end

local function miniBtn(parent, text, x, w, cb, accent)
	local b = new("TextButton", { Text = text, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = accent and T.accent or WHITE, BackgroundTransparency = accent and 0.7 or 0.9, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(w, 26), AutoButtonColor = false, Parent = parent }); rd(b, 8)
	if accent then onAccent(function(c) b.BackgroundColor3 = c end) end
	local base = accent and 0.7 or 0.9
	conn(b.MouseEnter, function() tw(b, 0.15, { BackgroundTransparency = base - 0.15 }) end)
	conn(b.MouseLeave, function() tw(b, 0.15, { BackgroundTransparency = base }) end)
	conn(b.Activated, function() pcall(cb) end)
	return b
end
local function btn(parent, name, cb, text)
	local r = row(parent, name)
	local b = miniBtn(r, text or "Run", -10, 78, cb, true)
	return r, b
end

local function opt(parent, name, flag, options, default, cb)
	F[flag] = default
	local r = row(parent, name)
	local b = miniBtn(r, default, -10, 118, function() end)
	b.Text = default
	UI[flag] = function(v) F[flag] = v; b.Text = v; if cb then pcall(cb, v) end; fire(flag) end
	b.Activated:Connect(function()
		local idx = table.find(options, F[flag]) or 0
		UI[flag](options[idx % #options + 1])
	end)
	return r
end

local listening
local function bind(parent, name, flag, default, cb)
	F[flag] = default
	local r = row(parent, name)
	local b
	b = miniBtn(r, default, -10, 118, function() b.Text = "press a key…"; listening = function(k) UI[flag](k) end end)
	UI[flag] = function(v) F[flag] = v; b.Text = v; if cb then pcall(cb, v) end; fire(flag) end
	return r
end

local function info(parent, text, h)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, h or 38), BackgroundTransparency = 1, LayoutOrder = lo(), Parent = parent })
	local l = label(r, text, 12, T.sub, Enum.Font.Gotham); l.Size = UDim2.fromScale(1, 1); l.TextWrapped = true; l.TextYAlignment = Enum.TextYAlignment.Top; l.Position = UDim2.fromOffset(4, 0)
	return l
end

-- wrapped chip selector (single select)
local function chips(parent, name, flag, options, default, cb)
	F[flag] = default
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, LayoutOrder = lo(), Parent = parent })
	rd(r, 10); stroke(r, WHITE, 0.93)
	if S.building then table.insert(S.rows[S.building], { r, name:lower() }) end
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = r })
	new("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = r })
	local l = label(r, name, 13, T.text); l.Size = UDim2.new(1, 0, 0, 34); l.LayoutOrder = 0
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = l })
	local wrap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = r })
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = wrap })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
	local btns = {}
	local function paint()
		for k, b in pairs(btns) do
			local on = F[flag] == k
			tw(b, 0.2, { BackgroundTransparency = on and 0.55 or 0.92, BackgroundColor3 = on and T.accent or WHITE })
		end
	end
	for i, o in ipairs(options) do
		local b = new("TextButton", { Text = o, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), AutoButtonColor = false, LayoutOrder = i, Parent = wrap })
		rd(b, 13); new("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), Parent = b })
		btns[o] = b
		conn(b.Activated, function() UI[flag](o) end)
	end
	UI[flag] = function(v) F[flag] = v; paint(); if cb then pcall(cb, v) end; fire(flag) end
	onAccent(function() paint() end)
	paint()
	return r
end

-- color picker row: hue slider with rainbow track + rainbow toggle
S.swatches = {}
local function getCol(flag)
	if F[flag .. "_rb"] then return Color3.fromHSV((os.clock() * 0.22) % 1, 0.75, 1) end
	return Color3.fromHSV((F[flag .. "_h"] or 0) / 360, F[flag .. "_s"] or 0.75, 1)
end
local function colr(parent, name, flag, hue, sat, cb)
	F[flag .. "_h"], F[flag .. "_s"], F[flag .. "_rb"] = hue, sat or 0.75, false
	local r = row(parent, name, 60)
	local sw = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = getCol(flag), Parent = r }); rd(sw, 11); stroke(sw, WHITE, 0.6)
	S.swatches[#S.swatches + 1] = { sw, flag }
	local rb = new("TextButton", { Text = "RGB", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 9), Size = UDim2.fromOffset(38, 20), AutoButtonColor = false, Parent = r }); rd(rb, 10)
	local track = new("Frame", { Position = UDim2.new(0, 12, 0, 42), Size = UDim2.new(1, -24, 0, 7), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = r }); rd(track, 4)
	local ks = {}
	for i = 0, 6 do ks[#ks + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.75, 1)) end
	new("UIGradient", { Color = ColorSequence.new(ks), Parent = track })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(hue / 360, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, Parent = track }); rd(knob, 7); stroke(knob, BLACK, 0.6)
	local function paint() sw.BackgroundColor3 = getCol(flag); rb.TextColor3 = F[flag .. "_rb"] and T.accent or T.sub; rb.BackgroundTransparency = F[flag .. "_rb"] and 0.8 or 0.92 end
	local function setHue(v) F[flag .. "_h"] = v; knob.Position = UDim2.fromScale(v / 360, 0.5); paint(); if cb then pcall(cb) end; fire(flag .. "_h") end
	UI[flag .. "_h"] = setHue
	UI[flag .. "_rb"] = function(v) F[flag .. "_rb"] = v and true or false; paint(); if cb then pcall(cb) end end
	conn(rb.Activated, function() UI[flag .. "_rb"](not F[flag .. "_rb"]) end)
	local dragging = false
	local scroller = parent:FindFirstAncestorOfClass("ScrollingFrame")
	local function fromX(x) setHue(math.floor(math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * 360)) end
	conn(r.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			local y = i.Position.Y - r.AbsolutePosition.Y
			if y > 30 * G.UIs.Scale then dragging = true; if scroller then scroller.ScrollingEnabled = false end; fromX(i.Position.X) end
		end
	end)
	conn(UIS.InputChanged, function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end end)
	conn(UIS.InputEnded, function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then dragging = false; if scroller then scroller.ScrollingEnabled = true end end end)
	return r
end

-- image / sample card grid (skyboxes, fonts, ...)
local function cardGrid(parent, flag, items, default, cw, ch, cb)
	F[flag] = default
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = parent })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(cw, ch), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local cards = {}
	local function paint()
		for k, c in pairs(cards) do
			local on = F[flag] == k
			tw(c.stroke, 0.2, { Transparency = on and 0 or 0.85, Thickness = on and 2 or 1 })
			tw(c.title, 0.2, { TextColor3 = on and WHITE or Color3.fromRGB(205, 205, 215) })
		end
	end
	for i, it in ipairs(items) do
		local b = new("TextButton", { Text = "", BackgroundColor3 = Color3.fromRGB(16, 16, 22), AutoButtonColor = false, ClipsDescendants = true, LayoutOrder = i, Parent = holder }); rd(b, 12)
		local st = new("UIStroke", { Thickness = 1, Color = T.accent, Transparency = 0.85, Parent = b })
		onAccent(function(c) st.Color = c end)
		if it.image then
			new("ImageLabel", { BackgroundTransparency = 1, Image = it.image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = b })
		end
		if it.tint then new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = it.tint, BackgroundTransparency = 0.72, BorderSizePixel = 0, Parent = b }) end
		if it.sample then
			local s = new("TextLabel", { BackgroundTransparency = 1, Text = it.sample, Font = it.font or Enum.Font.Gotham, TextSize = 22, TextColor3 = WHITE, Size = UDim2.new(1, 0, 1, -18), Parent = b })
			s.Name = "Sample"
		end
		local scrim = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = b })
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1), Parent = scrim })
		local t = new("TextLabel", { BackgroundTransparency = 1, Text = it.title, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -3), Size = UDim2.new(1, -12, 0, 14), Parent = b })
		cards[it.key] = { stroke = st, title = t, btn = b }
		conn(b.Activated, function() UI[flag](it.key) end)
	end
	UI[flag] = function(v) F[flag] = v; paint(); if cb then pcall(cb, v) end; fire(flag) end
	paint()
	return holder
end

----------------------------------------------------------------------
-- LIVE PREVIEW PANEL  (blocky dummy in a ViewportFrame + per-feature overlays)
----------------------------------------------------------------------
local PV = {}
PV.tabs = { Aimbot = true, Combat = true, ESP = true, Chams = true, Tracers = true, HUD = true, Movement = true, Fly = true, World = true, Skybox = true, Lighting = true, Teams = true }
PV.panel = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 56), Size = UDim2.new(0, PW, 1, -68), BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, Visible = false, Parent = G.Main })
rd(PV.panel, 16); stroke(PV.panel, WHITE, 0.92)
PV.title = label(PV.panel, "LIVE PREVIEW", 10, T.sub, Enum.Font.GothamBold); PV.title.Position = UDim2.fromOffset(14, 10); PV.title.Size = UDim2.new(1, -28, 0, 14)

-- group chips (Enemies / Teammates / Self)
PV.group = "Enemies"
PV.chips = {}
for i, g in ipairs({ "Enemies", "Teammates", "Self" }) do
	local b = new("TextButton", { Text = g, TextSize = 10, Font = Enum.Font.GothamMedium, TextColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Position = UDim2.fromOffset(8 + (i - 1) * 62, 28), Size = UDim2.fromOffset(g == "Teammates" and 66 or 56, 20), AutoButtonColor = false, Parent = PV.panel }); rd(b, 10)
	PV.chips[g] = b
end
do
	local x = 8
	for _, g in ipairs({ "Enemies", "Teammates", "Self" }) do
		local b = PV.chips[g]; b.Position = UDim2.fromOffset(x, 28); x += b.Size.X.Offset + 4
	end
end
local function paintChips()
	for g, b in pairs(PV.chips) do
		local on = PV.group == g
		b.TextColor3 = on and Pal[S.mode].text or Pal[S.mode].sub
		tw(b, 0.2, { BackgroundTransparency = on and 0.8 or 0.94 })
	end
end
for g, b in pairs(PV.chips) do conn(b.Activated, function() PV.group = g; paintChips() end) end

PV.stage = new("Frame", { Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 1, -92), BackgroundColor3 = Color3.fromRGB(6, 6, 9), BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = PV.panel })
rd(PV.stage, 12)
PV.info = label(PV.panel, "", 11, T.text, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
PV.info.AnchorPoint = Vector2.new(0, 1); PV.info.Position = UDim2.new(0, 8, 1, -6); PV.info.Size = UDim2.new(1, -16, 0, 30); PV.info.TextWrapped = true

PV.sky = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, Parent = PV.stage })
PV.fog = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(190, 195, 205), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = PV.stage })
PV.glow = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.9, .95), ImageTransparency = 0.5, Parent = PV.stage })
onAccent(function(c) PV.glow.ImageColor3 = c end)
PV.wall = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .52), Size = UDim2.fromScale(.9, .12), BackgroundColor3 = Color3.fromRGB(90, 90, 105), BackgroundTransparency = 0.3, Visible = false, BorderSizePixel = 0, Parent = PV.stage }); rd(PV.wall, 3)
PV.thumb = new("ImageLabel", { BackgroundTransparency = 1, Image = ("rbxthumb://type=Avatar&id=%d&w=352&h=352"):format(LP.UserId), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.95, .95), ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = PV.stage })
PV.vp = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.4, -0.7, 0.6), Parent = PV.stage })
PV.cam = new("Camera", { FieldOfView = 34, Parent = PV.vp }); PV.vp.CurrentCamera = PV.cam
PV.hl = new("Highlight", { FillColor = T.accent, OutlineColor = WHITE, FillTransparency = 0.45, OutlineTransparency = 0.05, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = PV.vp })
onAccent(function(c) PV.hl.FillColor = c end)

-- build the dummy (R6-style blocky figure, white, with hair + face)
PV.model = Instance.new("Model"); PV.model.Name = "Dummy"
PV.parts = {}
do
	local function part(name, size, pos, col, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Anchored, p.CanCollide, p.CFrame = name, size, true, false, CFrame.new(pos)
		p.Color, p.Material = col or Color3.fromRGB(244, 244, 250), Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = PV.model; PV.parts[name] = { part = p, off = pos }
		return p
	end
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Head; mesh.Scale = Vector3.new(1.25, 1.25, 1.25); mesh.Parent = head
	local face = Instance.new("Decal"); face.Texture = "rbxasset://textures/face.png"; face.Face = Enum.NormalId.Front; face.Parent = head
	part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	part("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
	part("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
	part("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
	part("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
	PV.model.Parent = PV.vp
	PV.hl.Adornee = PV.model
end
PV.yaw, PV.bob, PV.alpha = 0, 0, 0
PV.center = Vector3.new(0, 2.9, 0)
local function pvPose(yaw, bob, alpha, glow)
	local rot = CFrame.Angles(0, yaw, 0)
	for name, d in pairs(PV.parts) do
		d.part.CFrame = CFrame.new(0, bob, 0) * rot * CFrame.new(d.off)
		d.part.Transparency = alpha
		if glow then d.part.Color = glow; d.part.Material = Enum.Material.Neon
		else d.part.Color = Color3.fromRGB(244, 244, 250); d.part.Material = Enum.Material.SmoothPlastic end
	end
end
-- manual projection (viewport camera is fixed, so we can map world->stage px ourselves)
local function pvProject(p)
	local cf = PV.cam.CFrame
	local l = cf:PointToObjectSpace(p)
	local sz = PV.stage.AbsoluteSize / G.UIs.Scale
	local th = math.tan(math.rad(PV.cam.FieldOfView / 2))
	local nz = -l.Z
	if nz < 0.1 then return Vector2.new(-999, -999) end
	local ndcY = l.Y / (nz * th)
	local ndcX = l.X / (nz * th * (sz.X / sz.Y))
	return Vector2.new((ndcX * 0.5 + 0.5) * sz.X, (0.5 - ndcY * 0.5) * sz.Y)
end

-- overlays (2D)
PV.ov = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = PV.stage })
local function ovFrame(props) props.Parent = PV.ov; props.BorderSizePixel = 0; return new("Frame", props) end
PV.box = ovFrame({ BackgroundTransparency = 1, Visible = false }); PV.boxS = new("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = PV.box })
PV.boxFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 254), BackgroundTransparency = 0.88, BorderSizePixel = 0, Visible = false, Parent = PV.box })
PV.corners = {}
PV.name = new("TextLabel", { BackgroundTransparency = 1, Text = "Dummy", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, TextStrokeTransparency = 0.5, AnchorPoint = Vector2.new(.5, 1), Size = UDim2.fromOffset(120, 14), Visible = false, Parent = PV.ov })
PV.dist = new("TextLabel", { BackgroundTransparency = 1, Text = "42 studs", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Color3.fromRGB(210, 210, 220), TextStrokeTransparency = 0.5, AnchorPoint = Vector2.new(.5, 0), Size = UDim2.fromOffset(120, 12), Visible = false, Parent = PV.ov })
PV.hpbg = ovFrame({ BackgroundColor3 = Color3.fromRGB(14, 14, 14), Visible = false }); PV.hp = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, .8), BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = PV.hpbg })
PV.tracer = ovFrame({ BackgroundColor3 = WHITE, Visible = false })
PV.bones = {}
for i = 1, 9 do PV.bones[i] = ovFrame({ BackgroundColor3 = WHITE, Visible = false }) end
PV.fov = ovFrame({ BackgroundTransparency = 1, Visible = false }); rd(PV.fov, 9999); PV.fovS = new("UIStroke", { Thickness = 1.5, Color = T.accent, Transparency = 0.3, Parent = PV.fov })
PV.ring1 = ovFrame({ BackgroundTransparency = 1, Visible = false }); rd(PV.ring1, 9999); PV.ring1S = new("UIStroke", { Thickness = 2, Color = T.accent, Parent = PV.ring1 })
PV.ring2 = ovFrame({ BackgroundTransparency = 1, Visible = false }); rd(PV.ring2, 9999); PV.ring2S = new("UIStroke", { Thickness = 1.5, Color = T.accent, Parent = PV.ring2 })
PV.lockLine = ovFrame({ BackgroundColor3 = T.accent, BackgroundTransparency = 0.3, Visible = false })
PV.cursor = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Visible = false, Parent = PV.ov })
for _, d in ipairs({ { .5, 0, 2, 6 }, { .5, 1, 2, 6 }, { 0, .5, 6, 2 }, { 1, .5, 6, 2 } }) do
	local f = new("Frame", { AnchorPoint = Vector2.new(d[1], d[2]), Position = UDim2.fromScale(d[1], d[2]), Size = UDim2.fromOffset(d[3], d[4]), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = PV.cursor })
	onAccent(function(c) f.BackgroundColor3 = c end)
end
PV.hud = ovFrame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.fromOffset(112, 30), BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.1, Visible = false }); rd(PV.hud, 8)
PV.hudT = label(PV.hud, "Dummy · 42 studs", 9, WHITE, Enum.Font.GothamMedium); PV.hudT.Position = UDim2.fromOffset(8, 3); PV.hudT.Size = UDim2.new(1, -10, 0, 12)
PV.hudB = new("Frame", { Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -16, 0, 4), BackgroundColor3 = Color3.fromRGB(50, 50, 58), BorderSizePixel = 0, Parent = PV.hud }); rd(PV.hudB, 2)
PV.hudH = new("Frame", { Size = UDim2.fromScale(.8, 1), BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = PV.hudB }); rd(PV.hudH, 2)
PV.cross = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Visible = false, Parent = PV.ov })
PV.hitbox = ovFrame({ BackgroundTransparency = 1, Visible = false }); PV.hitboxS = new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(255, 120, 120), Parent = PV.hitbox })
PV.hitboxF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 120, 120), BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = PV.hitbox })
PV.streaks = {}
for i = 1, 6 do PV.streaks[i] = ovFrame({ BackgroundColor3 = Color3.fromRGB(255, 255, 254), BackgroundTransparency = 0.7, Size = UDim2.fromOffset(30, 1), Visible = false }) end
PV.trail = {}
for i = 1, 4 do local f = ovFrame({ AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = T.accent, Visible = false }); rd(f, 9); onAccent(function(c) f.BackgroundColor3 = c end); PV.trail[i] = f end
PV.badge = label(PV.stage, "", 10, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Right); PV.badge.AnchorPoint = Vector2.new(1, 0); PV.badge.Position = UDim2.new(1, -8, 0, 6); PV.badge.Size = UDim2.fromOffset(100, 12)
onAccent(function(c) PV.ring1S.Color = c; PV.ring2S.Color = c; PV.fovS.Color = c; PV.lockLine.BackgroundColor3 = c end)

PV.crossKey = ""
local function drawCross(container, style, size, gap, thick, col)
	local key = table.concat({ style, size, gap, thick, tostring(col) }, "|")
	if container:GetAttribute("key") == key then return end
	container:SetAttribute("key", key)
	for _, c in ipairs(container:GetChildren()) do c:Destroy() end
	local function bar(ax, ay, px, py, w, h)
		new("Frame", { AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(px, py), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
	end
	if style == "Cross" or style == "Plus" then
		local len = size
		bar(.5, 1, .5, .5, thick, len); container:FindFirstChildWhichIsA("Frame").Position = UDim2.new(.5, 0, .5, -gap)
		local f = container:GetChildren()
		f[1].Position = UDim2.new(.5, 0, .5, -gap)
		local b2 = new("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, gap), Size = UDim2.fromOffset(thick, len), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
		new("Frame", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(.5, -gap, .5, 0), Size = UDim2.fromOffset(len, thick), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
		new("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(.5, gap, .5, 0), Size = UDim2.fromOffset(len, thick), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
	elseif style == "Dot" then
		local d = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(thick * 3, thick * 3), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container }); rd(d, 99)
	elseif style == "Circle" then
		local c = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(size * 2 + gap, size * 2 + gap), BackgroundTransparency = 1, Parent = container }); rd(c, 999)
		new("UIStroke", { Thickness = thick, Color = col, Parent = c })
		local d = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(thick * 2, thick * 2), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container }); rd(d, 99)
	else -- "T-Shape"
		new("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(.5, gap, .5, 0), Size = UDim2.fromOffset(size, thick), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
		new("Frame", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(.5, -gap, .5, 0), Size = UDim2.fromOffset(size, thick), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
		new("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, gap), Size = UDim2.fromOffset(thick, size), BackgroundColor3 = col, BorderSizePixel = 0, Parent = container })
	end
end

-- which features should show; sky/fog/lighting scene
PV.skyUrl = nil
function PV.setSkyImage(url)
	PV.skyUrl = url
	PV.sky.Image = url or ""
end
PV.t = 0
local function chamColor()
	if PV.group == "Teammates" then return getCol("col_team") elseif PV.group == "Self" then return getCol("col_self") end
	return getCol("col_enemy")
end

function PV.step(t, dt)
	if not PV.panel.Visible then return end
	PV.t += dt
	local cur = S.current
	-- pose
	local flying = F.fly_on and (cur == "Fly" or cur == "Movement")
	local nocl = F.noclip and cur == "Movement"
	PV.yaw = math.sin(t * 0.6) * 0.55
	PV.bob = flying and (0.45 + math.sin(t * 2.2) * 0.25) or 0
	PV.alpha = nocl and (0.45 + 0.25 * math.sin(t * 3)) or 0
	local chamOn = (cur == "Chams" or cur == "ESP" or cur == "Teams") and F.cham_on
	local glowCol = (cur == "Teams") and chamColor() or (F.cham_accent and T.accent or getCol("col_cham"))
	if chamOn and F.cham_style == "Pulse" then glowCol = glowCol:Lerp(WHITE, 0.2 + 0.2 * math.sin(t * 3)) end
	pvPose(PV.yaw, PV.bob, PV.alpha, chamOn and glowCol or nil)
	PV.glow.ImageColor3 = chamOn and glowCol or T.accent
	local look = PV.center + Vector3.new(0, 0.2, 0)
	PV.cam.CFrame = CFrame.lookAt(look + Vector3.new(0, 0.6, -15.5), look)
	local tgt = (cur == "Aimbot" and F.aim_on) and (G.locked or (G.lastLocked and t - (G.lastLockT or 0) < 4 and G.lastLocked)) or nil
	if tgt and tgt.Parent then
		if PV.thumbId ~= tgt.UserId then PV.thumbId = tgt.UserId; PV.thumb.Image = ("rbxthumb://type=Avatar&id=%d&w=352&h=352"):format(tgt.UserId) end
		PV.thumb.Visible = true; PV.vp.Visible = false
	else
		if PV.thumbId ~= LP.UserId then PV.thumbId = LP.UserId; PV.thumb.Image = ("rbxthumb://type=Avatar&id=%d&w=352&h=352"):format(LP.UserId) end
		PV.thumb.Visible = F.pv_avatar and true or false
		PV.vp.Visible = not F.pv_avatar
	end
	PV.wall.Visible = nocl and true or false
	-- lighting scene
	local sceneSky = cur == "Skybox" or cur == "World" or cur == "Lighting"
	PV.sky.ImageTransparency = sceneSky and 0 or 1
	local bright = F.fullbright and 1 or math.clamp((F.tod or 14) / 24, 0, 1)
	local daylight = F.fullbright and 1 or math.clamp(math.sin(((F.tod or 14) / 24) * math.pi * 2 - math.pi / 2) * 0.5 + 0.5, 0.15, 1)
	if sceneSky then
		PV.vp.Ambient = Color3.fromRGB(70, 70, 90):Lerp(Color3.fromRGB(230, 230, 240), daylight)
		PV.sky.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(70, 70, 100), 1 - daylight)
		PV.fog.BackgroundTransparency = F.nofog and 1 or (0.78 - (F.fog_amt or 0) * 0.0035)
	else
		PV.vp.Ambient = Color3.fromRGB(150, 150, 165); PV.fog.BackgroundTransparency = 1
	end
	-- joints
	local p = function(n, o) return pvProject(Vector3.new(0, PV.bob, 0) + CFrame.Angles(0, PV.yaw, 0):VectorToWorldSpace(o)) end
	local headP = p("h", Vector3.new(0, 4.5, 0))
	local top = p("t", Vector3.new(0, 5.3, 0))
	local feet = p("f", Vector3.new(0, 0, 0))
	local cx = (top.X + feet.X) / 2
	local h = math.abs(feet.Y - top.Y); local w = h * 0.5
	local esp = F.esp_on and cur == "ESP"
	local showEsp = (cur == "ESP" or cur == "Teams") and F.esp_on
	-- box
	local gcol = chamColor()
	PV.box.Visible = showEsp and F.esp_box
	if PV.box.Visible then
		PV.box.Position = UDim2.fromOffset(cx - w / 2, top.Y); PV.box.Size = UDim2.fromOffset(w, h)
		PV.boxS.Color = gcol; PV.boxFill.Visible = F.esp_fill and true or false; PV.boxFill.BackgroundColor3 = gcol
	end
	PV.name.Visible = showEsp and F.esp_name
	PV.name.Text = F.esp_tool and "Dummy [Sword]" or "Dummy"
	PV.name.Position = UDim2.fromOffset(cx, top.Y - 3)
	PV.dist.Visible = showEsp and (F.esp_dist or F.esp_hptext)
	PV.dist.Text = (F.esp_dist and "42 studs" or "") .. ((F.esp_dist and F.esp_hptext) and "  ·  " or "") .. (F.esp_hptext and "87hp" or "")
	PV.dist.Position = UDim2.fromOffset(cx, feet.Y + 2)
	PV.hpbg.Visible = showEsp and F.esp_hp
	PV.hpbg.Position = UDim2.fromOffset(cx - w / 2 - 6, top.Y); PV.hpbg.Size = UDim2.fromOffset(3, h)
	PV.hp.Size = UDim2.fromScale(1, 0.55 + 0.35 * math.sin(t * 0.8))
	-- skeleton
	local sk = (cur == "ESP" or cur == "Tracers") and F.esp_on and F.esp_skel
	local joints = {
		{ Vector3.new(0, 4.5, 0), Vector3.new(0, 4, 0) }, { Vector3.new(0, 4, 0), Vector3.new(0, 2.2, 0) },
		{ Vector3.new(0, 4, 0), Vector3.new(-1.5, 2.3, 0) }, { Vector3.new(0, 4, 0), Vector3.new(1.5, 2.3, 0) },
		{ Vector3.new(0, 2.2, 0), Vector3.new(-0.5, 0.1, 0) }, { Vector3.new(0, 2.2, 0), Vector3.new(0.5, 0.1, 0) },
		{ Vector3.new(-1.5, 2.3, 0), Vector3.new(-1.5, 3.2, 0) }, { Vector3.new(1.5, 2.3, 0), Vector3.new(1.5, 3.2, 0) },
	}
	for i, b in ipairs(PV.bones) do
		local j = joints[i]
		b.Visible = sk and j ~= nil
		if b.Visible then line(b, p("a", j[1]), p("b", j[2]), 1.6); b.BackgroundColor3 = gcol end
	end
	-- tracer
	PV.tracer.Visible = (cur == "Tracers" or cur == "ESP") and F.esp_tracers
	if PV.tracer.Visible then
		local sz = PV.stage.AbsoluteSize / G.UIs.Scale
		local origin = F.tracer_origin == "Center" and Vector2.new(sz.X / 2, sz.Y / 2) or (F.tracer_origin == "Top" and Vector2.new(sz.X / 2, 0) or Vector2.new(sz.X / 2, sz.Y))
		line(PV.tracer, origin, Vector2.new(cx, feet.Y), F.tracer_thick or 1.5); PV.tracer.BackgroundColor3 = getCol("col_tracer")
	end
	-- chams
	local cham = (cur == "Chams" or cur == "ESP" or cur == "Teams") and F.cham_on
	PV.hl.Enabled = cham and not F.pv_avatar
	PV.thumb.ImageColor3 = cham and WHITE:Lerp(gcol, 0.4) or WHITE
	if cham then
		local c = glowCol
		PV.hl.FillColor = c
		local style = F.cham_style
		PV.hl.FillTransparency = style == "Outline" and 1 or (style == "Fresnel" and 0.85 or 0.75)
		PV.hl.OutlineColor = F.cham_outline and getCol("col_cham_out") or c
		PV.hl.OutlineTransparency = style == "Fill" and 0.7 or 0
		PV.hl.DepthMode = F.cham_vis and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
	end
	-- aimbot
	local aim = cur == "Aimbot" and F.aim_on
	PV.fov.Visible = (cur == "Aimbot") and F.aim_circle
	local fr = math.clamp((F.aim_fov or 150) / 500, 0.08, 1) * math.min(PV.stage.AbsoluteSize.X, PV.stage.AbsoluteSize.Y) / G.UIs.Scale * 0.95
	PV.fov.Size = UDim2.fromOffset(fr, fr); PV.fov.AnchorPoint = Vector2.new(.5, .5); PV.fov.Position = UDim2.fromOffset(headP.X, headP.Y)
	PV.ring1.Visible, PV.ring2.Visible, PV.lockLine.Visible, PV.cursor.Visible = aim, aim, aim, aim
	local lockedHl = aim and F.aim_hl
	if aim then
		local part = F.aim_part
		local tp = part == "Head" and headP or p("t", Vector3.new(0, 3.2, 0))
		-- simulated cursor: drifts around, then eases (by smoothness) toward the target
		local ph = (t * 0.45) % 3
		local drift = Vector2.new(math.sin(t * 1.3) * 60, math.cos(t * 1.1) * 40)
		PV.cur = PV.cur or tp + drift
		local pull = 1 - math.clamp((F.aim_smooth or 25) / 100, 0.02, 0.98)
		local tgt = ph < 1.6 and (tp + drift) or tp
		PV.cur = PV.cur:Lerp(tgt, math.clamp(dt * (2 + pull * 14), 0, 1))
		PV.cursor.Position = UDim2.fromOffset(PV.cur.X, PV.cur.Y)
		local locked = (PV.cur - tp).Magnitude < 8
		PV.lockLine.Visible = locked
		if locked then line(PV.lockLine, PV.cur, tp, 1) end
		local k = (t * 0.9) % 1
		PV.ring1.AnchorPoint = Vector2.new(.5, .5); PV.ring2.AnchorPoint = Vector2.new(.5, .5)
		PV.ring1.Position = UDim2.fromOffset(tp.X, tp.Y); PV.ring2.Position = UDim2.fromOffset(tp.X, tp.Y)
		PV.ring1.Size = UDim2.fromOffset(18 + k * 30, 18 + k * 30); PV.ring1S.Transparency = 0.1 + k * 0.9
		local k2 = (k + 0.5) % 1
		PV.ring2.Size = UDim2.fromOffset(18 + k2 * 30, 18 + k2 * 30); PV.ring2S.Transparency = 0.1 + k2 * 0.9
		PV.hud.Visible = F.aim_hud
		PV.hudT.Text = ("Dummy · %s"):format(locked and "LOCKED" or "scanning")
		PV.hudH.Size = UDim2.fromScale(0.55 + 0.35 * math.sin(t * 0.8), 1)
	else
		PV.hud.Visible = false
	end
	if lockedHl then PV.hl.Enabled = true; PV.hl.FillColor = T.accent; PV.hl.FillTransparency = 0.6; PV.hl.OutlineColor = T.accent end
	-- crosshair (HUD tab)
	PV.cross.Visible = (cur == "HUD" or cur == "Aimbot") and F.crosshair
	if PV.cross.Visible then drawCross(PV.cross, F.cross_style or "Cross", F.cross_size or 10, F.cross_gap or 4, F.cross_thick or 2, getCol("col_cross")) end
	-- hitbox
	local hb = cur == "Combat" and F.hb_on
	PV.hitbox.Visible = hb
	if hb then
		local s = (F.hb_size or 6) * 0.1 + 0.5
		local torso = p("t", Vector3.new(0, 3, 0))
		local px = h * 0.28 * s
		PV.hitbox.AnchorPoint = Vector2.new(.5, .5); PV.hitbox.Position = UDim2.fromOffset(torso.X, torso.Y); PV.hitbox.Size = UDim2.fromOffset(px * 1.4, px * 1.4)
		PV.hitboxF.BackgroundTransparency = 0.85 + 0.05 * math.sin(t * 4)
	end
	-- movement visuals
	local spd = (cur == "Movement" or cur == "Fly") and ((F.speed_on and F.speed or 16) / 200)
	for i, s in ipairs(PV.streaks) do
		s.Visible = spd and spd > 0.12 or false
		if s.Visible then
			local sz = PV.stage.AbsoluteSize / G.UIs.Scale
			local x = ((t * (120 + spd * 600) + i * 53) % (sz.X + 60)) - 30
			s.AnchorPoint = Vector2.new(1, .5); s.Position = UDim2.fromOffset(x, sz.Y * (0.2 + i * 0.11)); s.Size = UDim2.fromOffset(20 + spd * 90, 1)
		end
	end
	for i, f in ipairs(PV.trail) do
		f.Visible = flying and true or false
		if f.Visible then
			f.Position = UDim2.fromOffset(feet.X + math.sin(t * 3 + i) * 6, feet.Y + 10 + i * 14); f.Size = UDim2.fromOffset(16 - i * 3, 16 - i * 3); f.BackgroundTransparency = 0.3 + i * 0.16
		end
	end
	PV.glow.ImageTransparency = 0.5 + 0.12 * math.sin(t * 1.6)
	PV.badge.Text = tgt and tgt.DisplayName or (F.pv_avatar and "AVATAR" or "DUMMY")
	local names = {}
	if cur == "Aimbot" and F.aim_on then names[#names + 1] = "Aimbot · " .. (F.aim_part or "") end
	if showEsp and F.esp_box then names[#names + 1] = "Box" end
	if showEsp and F.esp_name then names[#names + 1] = "Name" end
	if sk then names[#names + 1] = "Skeleton" end
	if PV.tracer.Visible then names[#names + 1] = "Tracer" end
	if cham then names[#names + 1] = "Chams" end
	if flying then names[#names + 1] = "Fly" end
	if nocl then names[#names + 1] = "Noclip" end
	if hb then names[#names + 1] = "Hitbox" end
	if PV.cross.Visible then names[#names + 1] = "Crosshair" end
	if tgt then names[#names + 1] = "Locked: " .. tgt.DisplayName end
	PV.info.Text = #names > 0 and table.concat(names, "  ·  ") or "Turn a feature on to preview it"
end

function PV.refresh(tab)
	local show = PV.tabs[tab] and true or false
	if show ~= PVState.on then
		PVState.on = show
		PV.panel.Visible = show
		if show then PV.panel.Position = UDim2.new(1, 40, 0, 56); tw(PV.panel, 0.5, { Position = UDim2.new(1, -12, 0, 56) }) end
	end
	local titles = { Aimbot = "AIMBOT PREVIEW", ESP = "ESP PREVIEW", Chams = "CHAMS PREVIEW", Tracers = "TRACER PREVIEW", HUD = "CROSSHAIR PREVIEW", Movement = "MOVEMENT PREVIEW", Fly = "FLY PREVIEW", Combat = "HITBOX PREVIEW", World = "WORLD PREVIEW", Skybox = "SKYBOX PREVIEW", Lighting = "LIGHTING PREVIEW", Teams = "TEAM COLORS" }
	PV.title.Text = titles[tab] or "LIVE PREVIEW"
	PV.cur = nil
end
paintChips()

----------------------------------------------------------------------
-- DATA: skyboxes, fonts, profiles, helpers used by the pages
----------------------------------------------------------------------
local D_NEB = { 171410628, 171410649, 171410620, 171410666, 171410657, 171410636 }      -- Bk Dn Ft Lf Rt Up
local D_PUR = { 159454299, 159454296, 159454293, 159454286, 159454300, 159454288 }
local D_REAL = { 144933338, 144931530, 144933262, 144933244, 144933299, 144931564 }
local D_DEV = { 2570432999, 2570433005, 2570432998, 2570433000, 2570432997, 2570432996 }
local D_CLASSIC = { 600830446, 600831635, 600832720, 600886090, 600833862, 600835177 }
local function wrapSky(id) return { id, id, id, id, id, id } end
local SkyData = {
	{ key = "Nebula", faces = D_NEB, stars = 0 },
	{ key = "Purple Nebula", faces = D_PUR, stars = 0 },
	{ key = "Orange Nebula", faces = D_NEB, tint = Color3.fromRGB(255, 170, 110) },
	{ key = "Pink Nebula", faces = D_PUR, tint = Color3.fromRGB(255, 150, 200) },
	{ key = "Night", faces = D_NEB, tint = Color3.fromRGB(140, 165, 255), clock = 0 },
	{ key = "Space", faces = D_PUR, tint = Color3.fromRGB(205, 220, 255), clock = 0 },
	{ key = "Realistic Day", faces = D_REAL, clock = 14 },
	{ key = "Realistic Sunset", faces = D_REAL, tint = Color3.fromRGB(255, 185, 140), clock = 18 },
	{ key = "Dev Sky", faces = D_DEV },
	{ key = "Classic", faces = D_CLASSIC, clock = 14 },
	{ key = "Wrap A", faces = wrapSky(6372755569) },
	{ key = "Wrap B", faces = wrapSky(6593170625) },
	{ key = "Wrap C", faces = wrapSky(10258337305) },
}
local SkyIdx = {}
for _, d in ipairs(SkyData) do SkyIdx[d.key] = d end

local FontNames = { "Default", "Gotham", "SourceSans", "Montserrat", "Ubuntu", "Nunito", "Oswald", "Roboto", "RobotoMono", "Merriweather", "Michroma", "Jura", "Code", "Arcade", "Bangers", "SciFi", "Fantasy", "Cartoon", "Creepster", "Antique", "Highway", "IndieFlower", "PermanentMarker", "SpecialElite", "Sarpanch", "FredokaOne", "Kalam", "Garamond" }
local FontEnum = {}
for _, n in ipairs(FontNames) do
	if n ~= "Default" then local ok, e = pcall(function() return Enum.Font[n] end); if ok and e then FontEnum[n] = e end end
end
local FontList = { "Default" }
for _, n in ipairs(FontNames) do if FontEnum[n] then FontList[#FontList + 1] = n end end

local Profiles = {
	{ key = "rivals", name = "Rivals", note = "Fast duels: low smoothing, head lock, wall check on.", preset = { aim_part = "Head", aim_smooth = 18, aim_wall = true, aim_pred = 0.04, aim_fov = 140 } },
	{ key = "arsenal", name = "Arsenal", note = "Quick rounds: head lock, team check, tracers.", preset = { aim_part = "Head", aim_smooth = 25, aim_team = true, esp_tracers = true, aim_fov = 160 } },
	{ key = "da hood", name = "Da Hood", note = "Torso lock with prediction for fast movers.", preset = { aim_part = "Torso", aim_smooth = 12, aim_pred = 0.13, aim_wall = false, aim_fov = 200 } },
	{ key = "murder mystery", name = "MM2", note = "Role-colored ESP (murderer red / sheriff blue).", preset = { esp_on = true, esp_name = true, esp_box = true, mm2_roles = true } },
	{ key = "doors", name = "Doors", note = "Fullbright, speed boost and anti-AFK.", preset = { fullbright = true, speed_on = true, speed = 22, antiafk = true } },
	{ key = "blox fruits", name = "Blox Fruits", note = "Farm-friendly: anti-AFK and a mild speed boost.", preset = { antiafk = true, speed_on = true, speed = 24 } },
	{ key = "prison life", name = "Prison Life", note = "Team-aware aimbot with chams.", preset = { aim_team = true, cham_on = true, aim_part = "Torso", aim_smooth = 22 } },
}
local Profile = { name = "Universal", note = "No game-specific tweaks detected. Core tools are ready.", preset = {} }
do
	local gname = ""
	pcall(function() gname = (MPS:GetProductInfo(game.PlaceId).Name or ""):lower() end)
	for _, p in ipairs(Profiles) do if gname:find(p.key, 1, true) then Profile = p; break end end
end
local function applyPreset(p) for k, v in pairs(p.preset) do if UI[k] then pcall(UI[k], v) end end end
local executor = "Unknown"
pcall(function() executor = identifyexecutor() end)

-- lighting effect helpers
local function lightFx(class, name, props)
	local o = Lighting:FindFirstChild(name)
	if not o then o = Instance.new(class); o.Name = name; o.Parent = Lighting end
	for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
	return o
end
local function lightFxOff(name) local o = Lighting:FindFirstChild(name); if o then o:Destroy() end end

-- sky apply / reset
local function hazeSet(on)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then return end
	if on then
		if atm:GetAttribute("AmbDensity") == nil then atm:SetAttribute("AmbDensity", atm.Density); atm:SetAttribute("AmbHaze", atm.Haze); atm:SetAttribute("AmbGlare", atm.Glare) end
		atm.Density = 0; atm.Haze = 0; atm.Glare = 0
	elseif atm:GetAttribute("AmbDensity") ~= nil then
		atm.Density = atm:GetAttribute("AmbDensity"); atm.Haze = atm:GetAttribute("AmbHaze"); atm.Glare = atm:GetAttribute("AmbGlare")
	end
end
local function applySky(name)
	local d = SkyIdx[name]; if not d then return end
	local fog = { Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor }   -- skyboxes must never touch fog
	pcall(function()
		for _, o in ipairs(Lighting:GetChildren()) do
			if o:IsA("Sky") and o.Name ~= "AmbienceSky" then Orig.sky[o] = true; o.Parent = nil end
		end
		lightFxOff("AmbienceSky"); lightFxOff("AmbienceTint")
		local f = d.faces
		new("Sky", {
			Name = "AmbienceSky", SkyboxBk = "rbxassetid://" .. f[1], SkyboxDn = "rbxassetid://" .. f[2], SkyboxFt = "rbxassetid://" .. f[3],
			SkyboxLf = "rbxassetid://" .. f[4], SkyboxRt = "rbxassetid://" .. f[5], SkyboxUp = "rbxassetid://" .. f[6],
			StarCount = F.sky_stars or 0, CelestialBodiesShown = F.sky_celestial and true or false, Parent = Lighting,
		})
		pcall(function() Lighting.AmbienceSky.SkyboxOrientation = Vector3.new(0, F.sky_rot or 0, 0) end)
		if d.tint and F.sky_tint then lightFx("ColorCorrectionEffect", "AmbienceTint", { TintColor = WHITE:Lerp(d.tint, F.sky_tint_amt or 0.7) }) end
		if d.clock and F.sky_clock then Lighting.ClockTime = d.clock end
		hazeSet(F.sky_haze and true or false)
	end)
	if F.sky_fog_lock ~= false then
		Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = fog[1], fog[2], fog[3]
		task.defer(function() Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = fog[1], fog[2], fog[3] end)
	end
end
local function resetSky()
	lightFxOff("AmbienceSky"); lightFxOff("AmbienceTint")
	for o in pairs(Orig.sky) do pcall(function() o.Parent = Lighting end) end
	Orig.sky = {}
	pcall(hazeSet, false)
end

-- fonts
local FontState = { orig = setmetatable({}, { __mode = "k" }), game = nil, menu = nil, gconn = nil, mconn = nil }
local function isTextObj(d) return d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") end
local function ours(d) return d:IsDescendantOf(G.Gui) or (G.OV and d:IsDescendantOf(G.OV)) end
local function applyGameFont(name)
	if FontState.gconn then FontState.gconn:Disconnect(); FontState.gconn = nil end
	if name == "Default" or not FontEnum[name] then
		for d, f in pairs(FontState.orig) do pcall(function() d.Font = f end) end
		FontState.orig = setmetatable({}, { __mode = "k" }); FontState.game = nil
		return
	end
	local fe = FontEnum[name]; FontState.game = fe
	local function set(d)
		if isTextObj(d) and not ours(d) then
			if not FontState.orig[d] then FontState.orig[d] = d.Font end
			d.Font = fe
		end
	end
	local pg = LP:FindFirstChildOfClass("PlayerGui")
	task.spawn(function()
		local n = 0
		local roots = { pg }
		if F.font_world then roots[#roots + 1] = workspace end
		for _, r in ipairs(roots) do
			if r then for _, d in ipairs(r:GetDescendants()) do
				pcall(set, d); n += 1; if n % 300 == 0 then task.wait() end
			end end
		end
	end)
	if pg then FontState.gconn = pg.DescendantAdded:Connect(function(d) task.defer(function() pcall(set, d) end) end) end
end
local function applyMenuFont(name)
	if FontState.mconn then FontState.mconn:Disconnect(); FontState.mconn = nil end
	local fe = FontEnum[name]
	FontState.menu = fe
	local function set(d)
		if isTextObj(d) then
			if d:GetAttribute("of") == nil then d:SetAttribute("of", d.Font.Name) end
			d.Font = fe or Enum.Font[d:GetAttribute("of")]
		end
	end
	for _, d in ipairs(G.Gui:GetDescendants()) do pcall(set, d) end
	if G.OV then for _, d in ipairs(G.OV:GetDescendants()) do pcall(set, d) end end
	if fe then FontState.mconn = G.Gui.DescendantAdded:Connect(function(d) task.defer(function() pcall(set, d) end) end) end
end

-- waypoints
local Waypoints = {}
local function wpFile() return "Ambience/waypoints_" .. game.PlaceId .. ".json" end
local function wpSave()
	local out = {}
	for _, w in ipairs(Waypoints) do out[#out + 1] = { n = w.name, c = { w.cf:GetComponents() } } end
	pcall(function() if makefolder and not isfolder("Ambience") then makefolder("Ambience") end; if writefile then writefile(wpFile(), HttpService:JSONEncode(out)) end end)
end
local function wpLoad()
	pcall(function()
		if isfile and isfile(wpFile()) then
			for _, w in ipairs(HttpService:JSONDecode(readfile(wpFile()))) do Waypoints[#Waypoints + 1] = { name = w.n, cf = CFrame.new(table.unpack(w.c)) } end
		end
	end)
end
wpLoad()

-- config
genv.AmbienceConfigs = genv.AmbienceConfigs or {}
local Slots = { "Default", "PvP", "Farm", "Stealth", "Stream" }
local function cfgJSON()
	local data = {}
	for k, v in pairs(F) do if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then data[k] = v end end
	return HttpService:JSONEncode(data)
end
local function saveCfg(slot)
	local json = cfgJSON(); genv.AmbienceConfigs[slot] = json
	pcall(function() if makefolder and not isfolder("Ambience") then makefolder("Ambience") end; if writefile then writefile("Ambience/" .. slot .. ".json", json) end end)
	notify("Saved config · " .. slot)
end
local function loadCfg(slot)
	local json = genv.AmbienceConfigs[slot]
	pcall(function() if isfile and isfile("Ambience/" .. slot .. ".json") then json = readfile("Ambience/" .. slot .. ".json") end end)
	if not json then notify("No config in " .. slot); return end
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if ok then for k, v in pairs(data) do if UI[k] and k ~= "menukey" then pcall(UI[k], v) end end; notify("Loaded config · " .. slot) end
end

-- accent control
local function accentFromFlags()
	if F.rainbow then return end
	setAccent(Color3.fromHSV((F.hue or 266) / 360, (F.sat or 45) / 100, 1))
end
local AccentPresets = {
	{ "Amethyst", 266, 45 }, { "Ocean", 202, 55 }, { "Rose", 335, 45 }, { "Emerald", 144, 55 }, { "Ember", 22, 60 },
	{ "Gold", 44, 55 }, { "Mint", 166, 45 }, { "Crimson", 355, 62 }, { "Violet", 285, 60 }, { "Mono", 0, 0 },
}

----------------------------------------------------------------------
-- PAGES A: Aimbot / Combat / Teams / ESP / Chams / Tracers / HUD
----------------------------------------------------------------------
local Friends = {}
local FriendsBody

do -- AIMBOT
	local P = newPage("Aimbot", "Combat  ›  Aim assist")
	local s = sec(P, "Aimbot")
	tog(s, "Enabled", "aim_on")
	tog(s, "Hold right mouse (PC)", "aim_rmb", true)
	tog(s, "Sticky lock", "aim_sticky", false)
	tog(s, "Team check", "aim_team", true)
	tog(s, "Wall check", "aim_wall", true)
	tog(s, "Ignore friends", "aim_friends", true)
	opt(s, "Target part", "aim_part", { "Head", "Torso", "Root" }, "Head")
	opt(s, "Aim method", "aim_mode", { "Camera", "Mouse" }, "Camera")
	opt(s, "Priority", "aim_prio", { "Cursor", "Distance", "Lowest HP" }, "Cursor")
	local s2 = sec(P, "Tuning")
	sld(s2, "FOV", "aim_fov", 30, 500, 150, 5)
	sld(s2, "Smoothness", "aim_smooth", 0, 95, 25, 1, nil, "%")
	sld(s2, "Prediction", "aim_pred", 0, 0.3, 0, 0.01)
	sld(s2, "Max distance", "aim_max", 50, 2000, 800, 10)
	tog(s2, "Decouple movement from camera", "aim_decouple", true)
	info(s2, "Stops aimbot from dragging your WASD direction toward the target — your character keeps walking where you intend while the camera locks on.", 40)
	local sa = sec(P, "Silent aim (redirects your shots)")
	tog(sa, "Silent aim", "silent_on", false, function(v)
		if v and genv.__AmbienceSilentInstall and not genv.__AmbienceSilentInstall() then
			notify("Silent aim needs hookmetamethod (not supported here)"); task.defer(function() UI.silent_on(false) end)
		end
	end)
	opt(sa, "Circle origin", "silent_origin", { "Hand", "Cursor", "Center" }, "Hand")
	tog(sa, "Show circle", "silent_circle", true)
	sld(sa, "Silent FOV", "silent_fov", 20, 400, 120, 5)
	colr(sa, "Circle color", "col_sa", 266, 0.45)
	opt(sa, "Hit part", "sa_part", { "Head", "Torso", "Root", "Random" }, "Head")
	sld(sa, "Hit chance", "sa_hit", 1, 100, 100, 1, nil, "%")
	sld(sa, "Prediction", "sa_pred", 0, 0.3, 0, 0.01)
	tog(sa, "Team check", "sa_team", true)
	tog(sa, "Wall check", "sa_wall", false)
	tog(sa, "Only while shooting", "sa_shoot_only", true)
	tog(sa, "Only with a tool equipped", "sa_tool_only", true)
	tog(sa, "Redirect raycasts (guns)", "sa_ray", true)
	tog(sa, "Redirect Mouse.Hit / Target", "sa_mouse", true)
	tog(sa, "Redirect camera rays", "sa_camray", false)
	info(sa, "Works on games that aim with raycasts or Mouse.Hit (Prison Life, many gun games). Games that send their own hit data can't be redirected.", 46)
	local s3 = sec(P, "Visuals")
	tog(s3, "FOV circle", "aim_circle", true)
	colr(s3, "FOV color", "col_fov", 266, 0.45)
	tog(s3, "Highlight locked target", "aim_hl", true)
	tog(s3, "Target HUD", "aim_hud", true)
	tog(s3, "Hit markers", "hitmarker", true)
end

do -- COMBAT
	local P = newPage("Combat", "Combat  ›  Extras")
	local s = sec(P, "Triggerbot")
	tog(s, "Triggerbot", "trig_on", false)
	sld(s, "Delay (s)", "trig_delay", 0, 0.5, 0.05, 0.01)
	local s2 = sec(P, "Hitbox")
	tog(s2, "Hitbox expander", "hb_on", false)
	sld(s2, "Size", "hb_size", 2, 25, 6, 1)
	sld(s2, "Transparency", "hb_trans", 0, 1, 0.75, 0.05)
	info(s2, "Hitbox and triggerbot behave differently per game and some anti-cheats flag them.", 34)
end

do -- TEAMS
	local P = newPage("Teams", "Combat  ›  Teams & friends")
	local s = sec(P, "Filters")
	tog(s, "Hide teammates in ESP", "esp_team", false)
	tog(s, "Color by team", "team_colors", true)
	local s2 = sec(P, "Group colors")
	colr(s2, "Enemies", "col_enemy", 130, 0.75)
	colr(s2, "Teammates", "col_team", 210, 0.75)
	colr(s2, "Self", "col_self", 300, 0.6)
	local s3 = sec(P, "Friends (skipped by aimbot / hitbox)")
	btn(s3, "Refresh list", function() if genv.__AmbienceRefreshFriends then genv.__AmbienceRefreshFriends() end end, "Refresh")
	FriendsBody = sec(P, "In server")
end

do -- ESP
	local P = newPage("ESP", "Visuals  ›  ESP")
	local s = sec(P, "ESP")
	tog(s, "Enabled", "esp_on")
	tog(s, "Boxes", "esp_box", true)
	opt(s, "Box style", "esp_boxstyle", { "Full", "Corner" }, "Full")
	tog(s, "Box fill", "esp_fill", false)
	tog(s, "Names", "esp_name", true)
	tog(s, "Distance", "esp_dist", true)
	tog(s, "Health bar", "esp_hp", true)
	tog(s, "Skeleton", "esp_skel", false)
	tog(s, "Head dot", "esp_head", false)
	tog(s, "Held tool name", "esp_tool", false)
	tog(s, "Health number", "esp_hptext", false)
	tog(s, "Off-screen arrows", "esp_arrows", false)
	sld(s, "Max distance", "esp_max", 100, 3000, 1500, 50)
	sld(s, "Text size", "esp_tsize", 9, 18, 12, 1)
	chips(s, "Distance unit", "esp_unit", { "Studs", "Meters" }, "Studs")
	if Profile.name == "MM2" then tog(s, "Role colors (MM2)", "mm2_roles", true) else F.mm2_roles = false end
	local s2 = sec(P, "Preview")
	tog(s2, "Use my avatar instead of dummy", "pv_avatar", false)
end

do -- CHAMS
	local P = newPage("Chams", "Visuals  ›  Chams")
	local s = sec(P, "Chams")
	tog(s, "Enabled", "cham_on")
	chips(s, "Style", "cham_style", { "Fill", "Outline", "Fresnel", "Pulse" }, "Fill")
	sld(s, "Fill transparency", "cham_fill", 0, 1, 0.45, 0.05)
	tog(s, "Only when visible (occluded)", "cham_vis", false)
	tog(s, "Hit chams (flash on hit)", "hit_chams", true)
	tog(s, "Hit particles", "hit_particles", true)
	tog(s, "Separate outline color", "cham_outline", false)
	tog(s, "Self chams", "cham_self", false)
	tog(s, "Use accent color (glow)", "cham_accent", true)
	local s2 = sec(P, "Colors")
	colr(s2, "Fill", "col_cham", 266, 0.5)
	colr(s2, "Outline", "col_cham_out", 0, 0)
	local s3 = sec(P, "Preview")
	tog(s3, "Use my avatar instead of dummy", "pv_avatar_c", false, function(v) if UI.pv_avatar then UI.pv_avatar(v) end end)
end

do -- TRACERS
	local P = newPage("Tracers", "Visuals  ›  Tracers")
	local s = sec(P, "Tracers")
	tog(s, "Enabled", "esp_tracers")
	chips(s, "Origin", "tracer_origin", { "Bottom", "Center", "Top", "Mouse" }, "Bottom")
	sld(s, "Thickness", "tracer_thick", 1, 4, 1.5, 0.5)
	sld(s, "Max distance", "tracer_max", 100, 3000, 1500, 50)
	local s2 = sec(P, "Colors")
	colr(s2, "Tracer", "col_tracer", 130, 0.75)
end

do -- HUD
	local P = newPage("HUD", "Visuals  ›  Crosshair & HUD")
	local s = sec(P, "Crosshair")
	tog(s, "Custom crosshair", "crosshair", false)
	chips(s, "Style", "cross_style", { "Cross", "T-Shape", "Dot", "Circle" }, "Cross")
	sld(s, "Size", "cross_size", 3, 30, 10, 1)
	sld(s, "Gap", "cross_gap", 0, 14, 4, 1)
	sld(s, "Thickness", "cross_thick", 1, 5, 2, 1)
	colr(s, "Color", "col_cross", 266, 0.45)
	local s2 = sec(P, "On-screen")
	tog(s2, "Watermark", "wm", true)
	tog(s2, "FPS / ping chip", "fps", true)
	tog(s2, "Active features list", "arraylist", true)
	tog(s2, "Radar minimap", "radar", false)
	sld(s2, "Radar range", "radar_range", 50, 400, 150, 10)
	tog(s2, "Touch quick pad", "touchpad", false)
end

genv.__AmbienceRefreshFriends = function()
	if not FriendsBody then return end
	for _, c in ipairs(FriendsBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local prev = S.building; S.building = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local r, l = row(FriendsBody, p.DisplayName .. "  @" .. p.Name)
			l.Size = UDim2.new(0.55, 0, 0, 38); l.TextTruncate = Enum.TextTruncate.AtEnd
			local b; b = miniBtn(r, Friends[p.UserId] and "Friend ✓" or "Add", -10, 82, function()
				Friends[p.UserId] = not Friends[p.UserId] or nil
				b.Text = Friends[p.UserId] and "Friend ✓" or "Add"
			end, Friends[p.UserId])
		end
	end
	S.building = prev
end

----------------------------------------------------------------------
-- PAGES B: World / Skybox / Lighting / Movement / Fly / Players / Waypoints / Misc
----------------------------------------------------------------------
local function myParts()
	local ch = LP.Character
	return ch, ch and ch:FindFirstChildOfClass("Humanoid"), ch and ch:FindFirstChild("HumanoidRootPart")
end

do -- WORLD
	local P = newPage("World", "World  ›  Environment")
	local s = sec(P, "Light")
	tog(s, "Fullbright", "fullbright", false, function(v)
		if v then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false; Lighting.Ambient = WHITE; Lighting.OutdoorAmbient = WHITE
		else for _, k in ipairs({ "Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient" }) do Lighting[k] = Orig.light[k] end end
	end)
	tog(s, "Remove shadows", "noshadows", false, function(v) Lighting.GlobalShadows = not v end)
	sld(s, "Time of day", "tod", 0, 24, Orig.light.ClockTime, 0.25, function(v) Lighting.ClockTime = v end)
	sld(s, "Brightness", "bright", 0, 5, Orig.light.Brightness, 0.1, function(v) Lighting.Brightness = v end)
	sld(s, "Exposure", "expo", -3, 3, Orig.light.ExposureCompensation, 0.1, function(v) Lighting.ExposureCompensation = v end)
	local s2 = sec(P, "Fog")
	tog(s2, "Custom fog", "fog_on", false, function(v)
		if v then local a = (F.fog_amt or 40) / 100; Lighting.FogStart = 0; Lighting.FogEnd = math.max(60, 5000 * (1 - a) ^ 2 + 60)
		else Lighting.FogEnd = Orig.light.FogEnd; Lighting.FogStart = Orig.light.FogStart end
	end)
	sld(s2, "Density", "fog_amt", 0, 100, 40, 1, function(v) if F.fog_on then Lighting.FogEnd = math.max(60, 5000 * (1 - v / 100) ^ 2 + 60) end end, "%")
	tog(s2, "Remove fog", "nofog", false, function(v) if v then Lighting.FogEnd = 1e6 else Lighting.FogEnd = Orig.light.FogEnd end end)
	colr(s2, "Fog color", "col_fog", 210, 0.2, function() if F.fog_on then Lighting.FogColor = getCol("col_fog") end end)
	local s2b = sec(P, "Time")
	tog(s2b, "Day / night cycle", "time_cycle", false)
	sld(s2b, "Cycle speed (hours / s)", "time_speed", 0.05, 3, 0.3, 0.05)
	tog(s2b, "Freeze time", "freeze_time", false)
	local s3 = sec(P, "Camera & physics")
	sld(s3, "Field of view", "fov", 40, 120, Cam.FieldOfView, 1, function(v) Cam.FieldOfView = v end)
	sld(s3, "Max zoom", "zoom", 10, 1000, LP.CameraMaxZoomDistance, 10, function(v) pcall(function() LP.CameraMaxZoomDistance = v end) end)
	sld(s3, "Gravity", "gravity", 20, 300, workspace.Gravity, 1, function(v) workspace.Gravity = v end)
	local s4 = sec(P, "Freecam")
	tog(s4, "Freecam", "freecam_on", false, function(v) if genv.__AmbienceFreecam then genv.__AmbienceFreecam(v) end end)
	sld(s4, "Speed", "freecam_speed", 20, 400, 100, 10)
	bind(s4, "Toggle key", "freecam_bind", "None")
	info(s4, "WASD to move, Space / Ctrl for up and down, mouse to look. Your character stays put while you look around.", 34)
end


-- unfolded-cube "cutout" preview card for a skybox preset
local function skyCutoutCard(parent, item, order, selected, onClick)
	local b = new("TextButton", { Text = "", BackgroundColor3 = Color3.fromRGB(14, 14, 19), AutoButtonColor = false, Size = UDim2.fromOffset(150, 128), LayoutOrder = order, Parent = parent }); rd(b, 12)
	local st = new("UIStroke", { Thickness = selected and 2 or 1, Color = T.accent, Transparency = selected and 0 or 0.85, Parent = b })
	onAccent(function(c) st.Color = c end)
	local net = new("Frame", { Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(132, 92), BackgroundTransparency = 1, Parent = b })
	local faces = item.faces
	local cells = {
		{ faces[6], 0.33, 0, 0.34, 0.34 },   -- Up
		{ faces[4], 0, 0.34, 0.25, 0.34 },   -- Lf
		{ faces[3], 0.25, 0.34, 0.25, 0.34 }, -- Ft
		{ faces[5], 0.5, 0.34, 0.25, 0.34 },  -- Rt
		{ faces[1], 0.75, 0.34, 0.25, 0.34 }, -- Bk
		{ faces[2], 0.33, 0.68, 0.34, 0.34 }, -- Dn
	}
	for _, c in ipairs(cells) do
		local img = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, Image = "rbxassetid://" .. c[1], ScaleType = Enum.ScaleType.Crop, Position = UDim2.fromScale(c[2], c[3]), Size = UDim2.fromScale(c[4], c[5]), Parent = net })
		if item.tint then new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = item.tint, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = img }) end
	end
	local nm = new("TextLabel", { BackgroundTransparency = 1, Text = item.key, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = selected and WHITE or Color3.fromRGB(200, 200, 210), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 104), Size = UDim2.new(1, -16, 0, 16), Parent = b })
	conn(b.Activated, function() onClick(item.key) end)
	return { st = st, nm = nm }
end
local function buildSkyCards(parent, flag, items, default, cb)
	F[flag] = default
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = parent })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 128), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local cards = {}
	local function build()
		for _, c in ipairs(holder:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		cards = {}
		for i, it in ipairs(items) do cards[it.key] = skyCutoutCard(holder, it, i, F[flag] == it.key, function(k) UI[flag](k) end) end
	end
	UI[flag] = function(v) F[flag] = v; build(); if cb then pcall(cb, v) end; fire(flag) end
	build()
	return holder
end

do -- SKYBOX
	local P = newPage("Skybox", "World  ›  Skyboxes")
	local s = sec(P, "Presets (unfolded cutout preview)")
	tog(s, "Apply instantly on select", "sky_auto", true)
	buildSkyCards(s, "sky", SkyData, "Nebula", function(k)
		local d = SkyIdx[k]; if d then PV.setSkyImage("rbxassetid://" .. d.faces[3]) end
		if F.sky_auto then applySky(k) end
	end)
	PV.setSkyImage("rbxassetid://" .. SkyData[1].faces[3])
	btn(s, "Apply skybox", function() applySky(F.sky); notify("Skybox · " .. F.sky) end, "Apply")
	btn(s, "Reset to game sky", function() resetSky(); notify("Sky restored") end, "Reset")
	local s2 = sec(P, "Tuning")
	sld(s2, "Stars", "sky_stars", 0, 5000, 0, 50, function(v) local o = Lighting:FindFirstChild("AmbienceSky"); if o then o.StarCount = v end end)
	tog(s2, "Sun & moon", "sky_celestial", false, function(v) local o = Lighting:FindFirstChild("AmbienceSky"); if o then o.CelestialBodiesShown = v end end)
	sld(s2, "Rotate", "sky_rot", 0, 360, 0, 1, function(v) local o = Lighting:FindFirstChild("AmbienceSky"); if o then pcall(function() o.SkyboxOrientation = Vector3.new(0, v, 0) end) end end)
	tog(s2, "Keep game fog unchanged", "sky_fog_lock", true)
	tog(s2, "Clear atmosphere haze (clearer sky)", "sky_haze", false, function() if F.sky then applySky(F.sky) end end)
	tog(s2, "Apply preset tint", "sky_tint", false)
	sld(s2, "Tint strength", "sky_tint_amt", 0, 1, 0.7, 0.05)
	tog(s2, "Apply preset time of day", "sky_clock", false)
	info(s2, "Skybox faces are Roblox image assets. If one shows grey, that asset was removed; pick another preset.", 34)
end

do -- LIGHTING
	local P = newPage("Lighting", "World  ›  Post-processing")
	local s = sec(P, "Presets")
	local function resetFx() for _, n in ipairs({ "AmbienceBloom", "AmbienceRays", "AmbienceCC" }) do lightFxOff(n) end; for _, f in ipairs({ "bloom_on", "rays_on", "cc_on" }) do if UI[f] then F[f] = false; UI[f](false) end end end
	local presets = {
		Default = function() resetFx(); for _, k in ipairs({ "Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do Lighting[k] = Orig.light[k] end end,
		Bright = function() Lighting.Brightness = 3; Lighting.ClockTime = 13; Lighting.GlobalShadows = false end,
		Dusk = function() Lighting.ClockTime = 18.4; Lighting.Brightness = 1.6; Lighting.OutdoorAmbient = Color3.fromRGB(120, 90, 110); UI.rays_on(true) end,
		Midnight = function() Lighting.ClockTime = 0; Lighting.Brightness = 0.8; Lighting.OutdoorAmbient = Color3.fromRGB(40, 45, 80) end,
		Noir = function() UI.cc_on(true); UI.cc_sat(-1); UI.cc_con(0.25) end,
		Vivid = function() UI.cc_on(true); UI.cc_sat(0.6); UI.cc_con(0.12); UI.bloom_on(true) end,
		Warm = function() UI.cc_on(true); UI.cc_hue(30); UI.cc_tint(0.45) end,
		Cold = function() UI.cc_on(true); UI.cc_hue(210); UI.cc_tint(0.45) end,
		Dream = function() UI.bloom_on(true); UI.bloom_int(1.6); UI.cc_on(true); UI.cc_sat(0.3); UI.cc_hue(290); UI.cc_tint(0.25) end,
	}
	local order = { "Default", "Bright", "Dusk", "Midnight", "Noir", "Vivid", "Warm", "Cold", "Dream" }
	-- build effect controls first so presets can drive them
	local s2 = sec(P, "Bloom")
	tog(s2, "Bloom", "bloom_on", false, function(v) if v then lightFx("BloomEffect", "AmbienceBloom", { Intensity = F.bloom_int, Size = F.bloom_size, Threshold = F.bloom_thr }) else lightFxOff("AmbienceBloom") end end)
	sld(s2, "Intensity", "bloom_int", 0, 3, 0.6, 0.05, function(v) local o = Lighting:FindFirstChild("AmbienceBloom"); if o then o.Intensity = v end end)
	sld(s2, "Size", "bloom_size", 0, 56, 24, 1, function(v) local o = Lighting:FindFirstChild("AmbienceBloom"); if o then o.Size = v end end)
	sld(s2, "Threshold", "bloom_thr", 0, 3, 1, 0.05, function(v) local o = Lighting:FindFirstChild("AmbienceBloom"); if o then o.Threshold = v end end)
	local s3 = sec(P, "Sun rays")
	tog(s3, "Sun rays", "rays_on", false, function(v) if v then lightFx("SunRaysEffect", "AmbienceRays", { Intensity = F.rays_int, Spread = 0.6 }) else lightFxOff("AmbienceRays") end end)
	sld(s3, "Intensity", "rays_int", 0, 1, 0.25, 0.01, function(v) local o = Lighting:FindFirstChild("AmbienceRays"); if o then o.Intensity = v end end)
	local s4 = sec(P, "Color correction")
	local function cc() local o = Lighting:FindFirstChild("AmbienceCC"); if o then o.Brightness = F.cc_bri; o.Contrast = F.cc_con; o.Saturation = F.cc_sat; o.TintColor = WHITE:Lerp(Color3.fromHSV(F.cc_hue / 360, 1, 1), F.cc_tint) end end
	tog(s4, "Color correction", "cc_on", false, function(v) if v then lightFx("ColorCorrectionEffect", "AmbienceCC", {}); cc() else lightFxOff("AmbienceCC") end end)
	sld(s4, "Brightness", "cc_bri", -0.5, 0.5, 0, 0.01, cc)
	sld(s4, "Contrast", "cc_con", -1, 1, 0, 0.01, cc)
	sld(s4, "Saturation", "cc_sat", -1, 1.5, 0, 0.01, cc)
	sld(s4, "Tint hue", "cc_hue", 0, 360, 0, 1, cc)
	sld(s4, "Tint amount", "cc_tint", 0, 1, 0, 0.01, cc)
	-- presets chips on top (created last, ordered first via LayoutOrder trick)
	local pc = chips(s, "Preset", "light_preset", order, "Default", function(v) pcall(presets[v]); notify("Lighting · " .. v) end)
end

do -- MOVEMENT
	local P = newPage("Movement", "Player  ›  Movement")
	local s = sec(P, "Speed & jump")
	tog(s, "Speed", "speed_on", false); sld(s, "Walk speed", "speed", 16, 250, 32, 1)
	tog(s, "Sprint (hold Shift)", "sprint_on", false); sld(s, "Sprint multiplier", "sprint_mult", 1, 3, 1.6, 0.1)
	tog(s, "Jump power", "jump_on", false); sld(s, "Jump", "jump", 50, 350, 90, 1)
	tog(s, "Infinite jump", "inf_jump", false)
	tog(s, "Bunny hop (hold Space)", "bhop", false)
	local s2 = sec(P, "Collision & camera")
	tog(s2, "Noclip", "noclip", false)
	tog(s2, "Ctrl + click teleport", "clicktp", false)
	local sl = sec(P, "Shiftlock (PC-style)")
	tog(sl, "Shiftlock", "shiftlock", false)
	bind(sl, "Toggle key", "shiftlock_bind", "LeftShift")
	sld(sl, "Camera offset", "sl_offset", 0, 4, 1.75, 0.05)
	tog(sl, "Center dot", "sl_cross", true)
	info(sl, "Locks the mouse to the center, offsets the camera over your shoulder and turns your character with the camera. Mobile: use the SL button on the quick pad.", 46)
	local s3 = sec(P, "Safety")
	tog(s3, "Anti-void (return to last safe spot)", "antivoid", false)
	sld(s3, "Void height (Y)", "void_y", -1000, 0, -200, 10)
end

do -- FLY
	local P = newPage("Fly", "Player  ›  Flight")
	local s = sec(P, "Flight")
	tog(s, "Fly", "fly_on", false, function(v) if not v and genv.__AmbienceClean then genv.__AmbienceClean() end end)
	opt(s, "Mode", "fly_mode", { "Camera", "Classic", "Smooth" }, "Camera")
	sld(s, "Speed", "fly_speed", 10, 250, 60, 1)
	sld(s, "Vertical speed", "fly_vspeed", 10, 250, 60, 1)
	tog(s, "Noclip while flying", "fly_noclip", true)
	bind(s, "Toggle key", "fly_bind", "F")
	info(s, "PC: WASD + Space / Ctrl (or Q) to go up and down. Mobile: joystick + jump button.", 34)
end

do -- PLAYERS
	local P = newPage("Players", "Player  ›  Server")
	local s = sec(P, "Players")
	btn(s, "Refresh list", function() if genv.__AmbienceRefreshPlayers then genv.__AmbienceRefreshPlayers() end end, "Refresh")
	btn(s, "Stop spectating", function() G.spectating = nil; local _, h = myParts(); if h then Cam.CameraSubject = h end end, "Stop")
	G.PlayersBody = sec(P, "In server")
end
genv.__AmbienceRefreshPlayers = function()
	if not G.PlayersBody then return end
	for _, c in ipairs(G.PlayersBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local prev = S.building; S.building = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local r, l = row(G.PlayersBody, p.DisplayName .. "  @" .. p.Name)
			l.Size = UDim2.new(0.45, 0, 0, 38); l.TextTruncate = Enum.TextTruncate.AtEnd
			miniBtn(r, "TP", -10, 48, function() local _, _, hrp = myParts(); hrp.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3) end)
			miniBtn(r, "View", -64, 52, function()
				if G.spectating == p then G.spectating = nil; local _, h = myParts(); Cam.CameraSubject = h
				else G.spectating = p; Cam.CameraSubject = p.Character.Humanoid end
			end)
		end
	end
	S.building = prev
end

do -- WAYPOINTS
	local P = newPage("Waypoints", "Player  ›  Saved locations")
	local s = sec(P, "Save")
	local r = row(s, "Name")
	local tb = new("TextBox", { PlaceholderText = "My spot", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(150, 26), Parent = r }); rd(tb, 8)
	G.wpBox = tb
	btn(s, "Save current position", function()
		local _, _, hrp = myParts(); if not hrp then return end
		local nm = (tb.Text ~= "" and tb.Text) or ("Waypoint " .. (#Waypoints + 1))
		Waypoints[#Waypoints + 1] = { name = nm, cf = hrp.CFrame }; tb.Text = ""
		wpSave(); if genv.__AmbienceRebuildWP then genv.__AmbienceRebuildWP() end; notify("Saved · " .. nm)
	end, "Save")
	tog(s, "Smooth teleport (tween)", "wp_tween", false)
	tog(s, "Show markers in world", "wp_markers", true)
	G.WPBody = sec(P, "Saved")
end
genv.__AmbienceRebuildWP = function()
	for _, c in ipairs(G.WPBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local prev = S.building; S.building = nil
	for i, w in ipairs(Waypoints) do
		local r, l = row(G.WPBody, w.name)
		l.Size = UDim2.new(0.5, 0, 0, 38); l.TextTruncate = Enum.TextTruncate.AtEnd
		miniBtn(r, "Del", -10, 46, function() table.remove(Waypoints, i); wpSave(); genv.__AmbienceRebuildWP() end)
		miniBtn(r, "TP", -62, 46, function()
			local _, _, hrp = myParts(); if not hrp then return end
			if F.wp_tween then tw(hrp, 0.9, { CFrame = w.cf }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut) else hrp.CFrame = w.cf end
		end, true)
	end
	S.building = prev
end

do -- MISC
	local P = newPage("Misc", "Player  ›  Utility")
	local s = sec(P, "Quick")
	tog(s, "Anti-AFK", "antiafk", true)
	btn(s, "Quick waypoint (save here)", function()
		local _, _, hrp = myParts(); if not hrp then return end
		Waypoints[#Waypoints + 1] = { name = "Quick " .. (#Waypoints + 1), cf = hrp.CFrame }; wpSave(); genv.__AmbienceRebuildWP(); notify("Waypoint saved")
	end, "Save")
	btn(s, "Return to last waypoint", function()
		local _, _, hrp = myParts(); local w = Waypoints[#Waypoints]
		if hrp and w then hrp.CFrame = w.cf end
	end, "Go")
	btn(s, "Reset character", function() local _, h = myParts(); if h then h.Health = 0 end end, "Reset")
	local s2 = sec(P, "Server")
	btn(s2, "Rejoin", function() pcall(function() TPS:Teleport(game.PlaceId, LP) end) end, "Rejoin")
	btn(s2, "Server hop", function()
		task.spawn(function()
			local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
			local req = (request or http_request or (syn and syn.request) or (http and http.request))
			local list
			if req then
				local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
				if ok and res and (res.StatusCode == 200 or res.Success) then local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end); if ok2 then list = data.data end end
			end
			if list then
				local picks = {}
				for _, s in ipairs(list) do if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 1) then picks[#picks + 1] = s.id end end
				if #picks > 0 then pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId, picks[math.random(1, #picks)], LP) end); return end
			end
			notify("Couldn't list servers here — rejoining instead")
			pcall(function() TPS:Teleport(game.PlaceId, LP) end)
		end)
	end, "Hop")
	btn(s2, "Copy PlaceId", function() pcall(function() setclipboard(tostring(game.PlaceId)) end); notify("PlaceId copied") end, "Copy")
	btn(s2, "Copy JobId", function() pcall(function() setclipboard(game.JobId) end); notify("JobId copied") end, "Copy")
	tog(s, "Join / leave alerts", "join_alerts", true)
	local sv = sec(P, "Server info")
	local function kvl(k) local r = row(sv, k); local l = label(r, "", 12, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Right); l.AnchorPoint = Vector2.new(1, 0); l.Position = UDim2.new(1, -12, 0, 0); l.Size = UDim2.fromOffset(190, 38); return l end
	G.srvPlayers, G.srvPing, G.srvUp = kvl("Players"), kvl("Ping"), kvl("Session time")
	local s3 = sec(P, "Performance")
	sld(s3, "FPS cap", "fpscap", 30, 360, 60, 10, function(v) pcall(function() setfpscap(v) end) end)
	tog(s3, "Lower graphics quality", "lowgfx", false, function(v) pcall(function() settings().Rendering.QualityLevel = v and 1 or Enum.QualityLevel.Automatic end) end)
end

----------------------------------------------------------------------
-- PAGES C: Colors / Effects / Fonts / Configs / Remote Spy / Game / Settings / Home
----------------------------------------------------------------------
local function modeCards(parent)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 134), BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, LayoutOrder = lo(), Parent = parent })
	rd(r, 12); stroke(r, WHITE, 0.93)
	if S.building then table.insert(S.rows[S.building], { r, "color mode theme light dark system" }) end
	local ic = makeIcon(r, "palette", 20); ic.Position = UDim2.fromOffset(12, 10)
	local ttl = label(r, "Color mode", 14, T.text); ttl.Position = UDim2.fromOffset(40, 8); ttl.Size = UDim2.new(1, -50, 0, 22)
	local cards = {}
	local faceCol = { Light = Color3.fromRGB(243, 243, 245), Dark = Color3.fromRGB(34, 34, 38) }
	local innerCol = { Light = WHITE, Dark = Color3.fromRGB(22, 22, 26) }
	local lineCol = { Light = Color3.fromRGB(150, 150, 158), Dark = Color3.fromRGB(125, 125, 135) }
	for i, k in ipairs({ "Light", "Dark", "System" }) do
		local face = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = k == "System" and WHITE or faceCol[k], BackgroundTransparency = 0, Position = UDim2.new((i - 1) / 3, 8, 0, 38), Size = UDim2.new(1 / 3, -12, 0, 64), Parent = r })
		rd(face, 14)
		local st = new("UIStroke", { Thickness = 2.5, Color = T.accent, Transparency = 1, Parent = face })
		local inner = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = k == "System" and WHITE or innerCol[k], BorderSizePixel = 0, Parent = face }); rd(inner, 9)
		new("UIStroke", { Thickness = 1, Color = k == "Light" and Color3.fromRGB(222, 222, 228) or Color3.fromRGB(52, 52, 60), Transparency = 0.2, Parent = inner })
		if k == "System" then
			local function split(a, b) return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.5, a), ColorSequenceKeypoint.new(0.501, b), ColorSequenceKeypoint.new(1, b) }) end
			new("UIGradient", { Rotation = 28, Color = split(faceCol.Light, faceCol.Dark), Parent = face })
			new("UIGradient", { Rotation = 28, Color = split(WHITE, innerCol.Dark), Parent = inner })
		end
		local lc = k == "System" and lineCol.Light or lineCol[k]
		for n, w in ipairs({ 0.55, 0.32 }) do
			local ln = new("Frame", { Position = UDim2.new(0, 8, 0, 8 + (n - 1) * 7), Size = UDim2.new(w, 0, 0, 3), BackgroundColor3 = lc, BorderSizePixel = 0, Parent = inner }); rd(ln, 2)
		end
		local dot = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -7, 1, -7), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = inner }); rd(dot, 6)
		onAccent(function(c) dot.BackgroundColor3 = c; st.Color = c end)
		local lbl = label(r, k, 12, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
		lbl.Position = UDim2.new((i - 1) / 3, 8, 0, 106); lbl.Size = UDim2.new(1 / 3, -12, 0, 20)
		cards[k] = { st = st, lbl = lbl }
		conn(face.Activated, function() UI.cmode(k) end)
	end
	F.cmode = "Dark"
	local function paint()
		for k, c in pairs(cards) do
			local on = F.cmode == k
			tw(c.st, 0.2, { Transparency = on and 0 or 1 })
			c.lbl.TextColor3 = on and T.accent or Pal[S.mode].sub
			c.lbl.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
		end
	end
	onAccent(function() paint() end)
	UI.cmode = function(v) F.cmode = v; applyMode(v); paint(); fire("cmode") end
	paint()
end

do -- COLORS
	local P = newPage("Colors", "Menu  ›  Appearance")
	local s = sec(P, "Appearance")
	modeCards(s)
	local s2 = sec(P, "Accent")
	-- preset swatches
	local r, l = row(s2, "Presets", 70)
	l.Size = UDim2.new(1, -20, 0, 28)
	local sw = new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1, Parent = r })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = sw })
	local swb = {}
	for _, p in ipairs(AccentPresets) do
		local c = Color3.fromHSV(p[2] / 360, p[3] / 100, 1)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = c, Size = UDim2.fromOffset(26, 26), Parent = sw }); rd(b, 13)
		local st = new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 1, Parent = b })
		swb[p[1]] = st
		conn(b.Activated, function()
			if UI.rainbow and F.rainbow then UI.rainbow(false) end
			UI.hue(p[2]); UI.sat(p[3])
			for n, s2 in pairs(swb) do tw(s2, 0.2, { Transparency = n == p[1] and 0 or 1 }) end
		end)
	end
	sld(s2, "Hue", "hue", 0, 360, 266, 1, accentFromFlags)
	sld(s2, "Saturation", "sat", 0, 100, 45, 1, accentFromFlags, "%")
	tog(s2, "Rainbow accent", "rainbow", false, function(v) S.rainbow = v; if not v then accentFromFlags() end end)
	sld(s2, "Rainbow speed", "rb_speed", 1, 20, 6, 1)
	local s3 = sec(P, "Window")
	chips(s3, "Style", "win_style", { "Glass", "Frosted", "Solid", "Clear" }, "Glass", function(v)
		local m = { Glass = { 0.1, 8 }, Frosted = { 0.3, 20 }, Solid = { 0, 0 }, Clear = { 0.5, 4 } }
		local d = m[v]; if UI.glass then UI.glass(d[1]) end; if UI.blur_amt then UI.blur_amt(d[2]) end
	end)
	sld(s3, "Glass opacity", "glass", 0, 0.7, 0.1, 0.01, function(v) G.Win.BackgroundTransparency = v end)
end

do -- EFFECTS
	local P = newPage("Effects", "Menu  ›  Animated backgrounds")
	local s = sec(P, "Background")
	chips(s, "Effect", "fx", FXList, "Stars", function(v) setFX(v) end)
	sld(s, "Speed", "fx_speed", 0.2, 3, 1, 0.1, function(v) S.fxSpeed = v end, "x")
	sld(s, "Density", "fx_density", 0.3, 2.5, 1, 0.1, function(v) S.fxDensity = v; task.defer(function() if fxName ~= "Off" then setFX(fxName) end end) end, "x")
	btn(s, "Random effect", function() UI.fx(FXList[math.random(2, #FXList)]) end, "Shuffle")
	info(s, "Effects follow your accent color where it makes sense (Topographic, Grid, Waves, Matrix, Bubbles, Orbs).", 34)
end

do -- FONTS
	local P = newPage("Fonts", "Menu  ›  Typography")
	local function items()
		local t = {}
		for _, n in ipairs(FontList) do t[#t + 1] = { key = n, title = n == "Default" and "Default" or n, sample = "Aa", font = FontEnum[n] or Enum.Font.Gotham } end
		return t
	end
	local s = sec(P, "Menu font")
	cardGrid(s, "menu_font", items(), "Default", 98, 62, function(k) applyMenuFont(k == "Default" and "Default" or k) end)
	local s2 = sec(P, "In-game font")
	info(s2, "Changes the font of the game's own text (menus, chat bubbles, HUD). Reversible.", 30)
	tog(s2, "Include world text (billboards / signs)", "font_world", false)
	cardGrid(s2, "game_font", items(), "Default", 98, 62, function(k) applyGameFont(k) end)
	btn(s2, "Restore game fonts", function() UI.game_font("Default"); notify("Game fonts restored") end, "Restore")
end

do -- CONFIGS
	local P = newPage("Configs", "Menu  ›  Profiles")
	local s = sec(P, "Slots")
	for _, slot in ipairs(Slots) do
		local r = row(s, slot)
		miniBtn(r, "Save", -10, 56, function() saveCfg(slot) end)
		miniBtn(r, "Load", -72, 56, function() loadCfg(slot) end, true)
	end
	local s2 = sec(P, "Tools")
	btn(s2, "Copy config to clipboard", function() pcall(function() setclipboard(cfgJSON()) end); notify("Config copied") end, "Copy")
	btn(s2, "Reset all to defaults", function() if genv.__AmbienceReset then genv.__AmbienceReset() end end, "Reset")
	local r = row(s2, "Import from clipboard")
	miniBtn(r, "Import", -10, 70, function()
		local ok, txt = pcall(function() return getclipboard() end)
		if not ok or not txt or txt == "" then notify("Clipboard is empty or unavailable"); return end
		local ok2, data = pcall(function() return HttpService:JSONDecode(txt) end)
		if ok2 and type(data) == "table" then
			for k, v in pairs(data) do if UI[k] and k ~= "menukey" then pcall(UI[k], v) end end
			notify("Config imported")
		else notify("Clipboard doesn't look like an Ambience config") end
	end, true)
	tog(s2, "Auto-load Default slot at start", "cfg_auto", false)
end

do -- REMOTE SPY
	local P = newPage("Remote Spy", "Menu  ›  Developer tools")
	local s = sec(P, "Logger")
	G.spyCount = 0
	tog(s, "Log remote calls", "spy_on", false, function(v)
		if not v then return end
		local ok = pcall(function()
			if G.spyHooked then return end
			local old
			local fn = function(self, ...)
				local m = getnamecallmethod()
				if F.spy_on and (m == "FireServer" or m == "InvokeServer") then
					local args = { ... }; local inst = self
					task.defer(function() if genv.__AmbienceSpyLog then pcall(genv.__AmbienceSpyLog, inst, m, args) end end)
				end
				return old(self, ...)
			end
			old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(fn) or fn)
			G.spyHooked = true
		end)
		if not ok or not G.spyHooked then notify("Remote spy unsupported on this executor"); task.defer(function() UI.spy_on(false) end) end
	end)
	btn(s, "Clear log", function() for _, c in ipairs(G.SpyBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end; G.spyCount = 0 end, "Clear")
	info(s, "Read-only: logs FireServer / InvokeServer calls (name, path, arguments). Tap Copy to grab the path.", 34)
	G.SpyBody = sec(P, "Calls")
end
local function argStr(v)
	local t = typeof(v)
	if t == "string" then return '"' .. v:sub(1, 22) .. (#v > 22 and "…" or "") .. '"' end
	if t == "Instance" then return v.Name end
	if t == "table" then return "{…}" end
	return tostring(v):sub(1, 26)
end
genv.__AmbienceSpyLog = function(inst, m, args)
	if typeof(inst) ~= "Instance" or not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then return end
	G.spyCount += 1
	local prev = S.building; S.building = nil
	local r = row(G.SpyBody, ("%s · %s"):format(m == "FireServer" and "Fire" or "Invoke", inst.Name), 52)
	r.LayoutOrder = -G.spyCount
	local parts = {}
	for i, a in ipairs(args) do if i > 5 then parts[#parts + 1] = "…"; break end; parts[#parts + 1] = argStr(a) end
	local sub = label(r, table.concat(parts, ", "), 10, T.sub, Enum.Font.Code); sub.Position = UDim2.fromOffset(12, 26); sub.Size = UDim2.new(1, -90, 0, 18); sub.TextTruncate = Enum.TextTruncate.AtEnd
	local path = inst:GetFullName()
	miniBtn(r, "Copy", -10, 52, function() pcall(function() setclipboard(path) end); notify("Path copied") end)
	S.building = prev
	local kids = G.SpyBody:GetChildren()
	if #kids > 70 then for _, c in ipairs(kids) do if c:IsA("Frame") and c.LayoutOrder == -(G.spyCount - 70) then c:Destroy() end end end
end

do -- GAME
	local P = newPage("Game", "Menu  ›  Detected game")
	local s = sec(P, Profile.name .. " profile")
	info(s, Profile.note, 34)
	btn(s, "Apply preset", function() applyPreset(Profile); notify(Profile.name .. " preset applied") end, "Apply")
	local s2 = sec(P, "Details")
	local function kv(k, v) local r = row(s2, k); local l = label(r, v, 12, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Right); l.AnchorPoint = Vector2.new(1, 0); l.Position = UDim2.new(1, -12, 0, 0); l.Size = UDim2.fromOffset(190, 38); l.TextTruncate = Enum.TextTruncate.AtEnd end
	kv("Game", Profile.name); kv("PlaceId", tostring(game.PlaceId)); kv("Executor", executor)
end

do -- SETTINGS
	local P = newPage("Settings", "Menu  ›  Preferences")
	local s = sec(P, "Menu")
	bind(s, "Menu key", "menukey", "RightShift")
	tog(s, "Notifications", "toasts", true)
	tog(s, "Background blur", "blur", true, function(v) if G.isOpen then tw(G.blur, 0.3, { Size = v and (F.blur_amt or 8) or 0 }) end end)
	sld(s, "Blur amount", "blur_amt", 0, 24, 8, 1, function(v) if G.isOpen and F.blur then G.blur.Size = v end end)
	sld(s, "UI scale", "uiscale", 0.5, 1.2, 1, 0.05, function() autoScale() end, "x")
	tog(s, "Compact size", "compact", false, function() autoScale() end)
	local s2 = sec(P, "Keybinds")
	bind(s2, "Toggle aimbot", "aim_bind", "None")
	bind(s2, "Toggle ESP", "esp_bind", "None")
	bind(s2, "Toggle noclip", "noclip_bind", "None")
	local s3 = sec(P, "Danger zone")
	btn(s3, "Unload Ambience", function() confirm("Unload Ambience?", "Everything gets restored and the menu is removed.", function() genv.AmbienceUnload() end) end, "Unload")
end

do -- HOME (built last so quick toggles can bind to real flags)
	local P = newPage("Home", "Welcome")
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, LayoutOrder = lo(), Parent = P }); rd(card, 14); stroke(card, WHITE, 0.92)
	local hs = new("ImageLabel", { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(28, 28, 34), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(LP.UserId), Parent = card }); rd(hs, 32)
	local hst = stroke(hs, T.accent, 0.2, 2); onAccent(function(c) hst.Color = c end)
	local a = label(card, "Welcome, " .. LP.DisplayName, 16, T.text, Enum.Font.GothamBold); a.Position = UDim2.fromOffset(92, 18); a.Size = UDim2.new(1, -100, 0, 22)
	local b = label(card, ("%s  ·  %s"):format(Profile.name, executor), 12, T.sub, Enum.Font.Gotham); b.Position = UDim2.fromOffset(92, 42); b.Size = UDim2.new(1, -100, 0, 16)
	local c = label(card, Profile.note, 11, T.sub, Enum.Font.Gotham); c.Position = UDim2.fromOffset(92, 60); c.Size = UDim2.new(1, -100, 0, 28); c.TextWrapped = true; c.TextYAlignment = Enum.TextYAlignment.Top
	local s = sec(P, "Quick toggles")
	local function qtog(name, flag)
		tog(s, name, "q_" .. flag, F[flag], function(v) if UI[flag] and F[flag] ~= v then UI[flag](v) end end)
		watch(flag, function(v) if F["q_" .. flag] ~= v then UI["q_" .. flag](v) end end)
	end
	qtog("Aimbot", "aim_on"); qtog("ESP", "esp_on"); qtog("Chams", "cham_on"); qtog("Tracers", "esp_tracers"); qtog("Fly", "fly_on"); qtog("Noclip", "noclip"); qtog("Fullbright", "fullbright")
	btn(s, "Apply " .. Profile.name .. " preset", function() applyPreset(Profile); notify(Profile.name .. " preset applied") end, "Apply")
	local s2 = sec(P, "Status")
	local fr, fl = row(s2, "Performance")
	G.fpsL = label(fr, "", 12, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Right); G.fpsL.AnchorPoint = Vector2.new(1, 0); G.fpsL.Position = UDim2.new(1, -12, 0, 0); G.fpsL.Size = UDim2.fromOffset(170, 38)
	local s3 = sec(P, "What's new")
	info(s3, "• Live dummy previews for aimbot, ESP, chams, tracers, fly, skyboxes\n• Light / Dark / System color mode + rainbow accent\n• 15 animated backgrounds, in-game font changer, waypoints, remote spy", 64)
end

----------------------------------------------------------------------
-- IN-WORLD OVERLAYS (ESP / skeleton / tracers / aimbot HUD / radar / chips)
----------------------------------------------------------------------
G.OV = new("ScreenGui", { Name = "AmbienceOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = GuiParent })
local function ovf(props)      -- overlay frame that never gets theme-skinned
	local col = props.BackgroundColor3; props.BackgroundColor3 = nil
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	local f = new("Frame", props)
	if col then f.BackgroundColor3 = col end
	return f
end
local OVC = Color3.fromRGB(255, 255, 254)

local ESP = {}
local function espMake()
	local o = {}
	o.box = new("Frame", { BackgroundTransparency = 1, Visible = false, Parent = G.OV }); o.stroke = new("UIStroke", { Color = OVC, Thickness = 1.5, Parent = o.box })
	o.fill = ovf({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = OVC, BackgroundTransparency = 0.86, Visible = false, Parent = o.box })
	o.corners = {}
	for i = 1, 8 do o.corners[i] = ovf({ BackgroundColor3 = OVC, Visible = false, Parent = G.OV }) end
	o.name = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = OVC, Font = Enum.Font.GothamMedium, TextSize = 12, TextStrokeTransparency = 0.5, Size = UDim2.fromOffset(200, 14), AnchorPoint = Vector2.new(0.5, 1), Visible = false, Parent = G.OV })
	o.dist = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(210, 210, 220), Font = Enum.Font.Gotham, TextSize = 11, TextStrokeTransparency = 0.5, Size = UDim2.fromOffset(200, 12), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = G.OV })
	o.hpbg = ovf({ BackgroundColor3 = Color3.fromRGB(15, 15, 15), Visible = false, Parent = G.OV })
	o.hp = ovf({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(80, 255, 120), Parent = o.hpbg })
	o.line = ovf({ BackgroundColor3 = OVC, Visible = false, Parent = G.OV })
	o.arrow = new("TextLabel", { BackgroundTransparency = 1, Text = "▶", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = OVC, Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(.5, .5), Visible = false, Parent = G.OV })
	o.head = ovf({ AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = OVC, Visible = false, Parent = G.OV }); rd(o.head, 4)
	o.bones = {}
	for i = 1, 14 do o.bones[i] = ovf({ BackgroundColor3 = OVC, Visible = false, Parent = G.OV }) end
	o.hl = new("Highlight", { FillTransparency = 0.5, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = G.OV })
	return o
end
local function espHide(o)
	o.box.Visible = false; o.fill.Visible = false
	for _, c in ipairs(o.corners) do c.Visible = false end
	o.name.Visible, o.dist.Visible, o.hpbg.Visible, o.line.Visible, o.head.Visible, o.hl.Enabled, o.arrow.Visible = false, false, false, false, false, false, false
	for _, b in ipairs(o.bones) do b.Visible = false end
end
local function espKill(plr)
	local o = ESP[plr]; if not o then return end
	for _, v in pairs(o) do
		if typeof(v) == "Instance" then v:Destroy()
		elseif type(v) == "table" then for _, x in ipairs(v) do pcall(function() x:Destroy() end) end end
	end
	ESP[plr] = nil
end
conn(Players.PlayerRemoving, espKill)

local function validChar(plr)
	local ch = plr.Character; if not ch then return end
	local hum, hrp = ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return ch, hum, hrp end
end
local function sameTeam(plr) return plr.Team ~= nil and plr.Team == LP.Team end
local function roleColor(plr)
	if not (F.mm2_roles and Profile.name == "MM2") then return nil end
	local function has(n) return (plr.Character and plr.Character:FindFirstChild(n)) or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild(n)) end
	if has("Knife") then return Color3.fromRGB(255, 70, 70) end
	if has("Gun") then return Color3.fromRGB(80, 150, 255) end
end
local function playerCol(plr)
	local r = roleColor(plr); if r then return r end
	if Friends[plr.UserId] then return getCol("col_team") end
	if F.team_colors and sameTeam(plr) then return getCol("col_team") end
	return getCol("col_enemy")
end
local function skelPairs(ch)
	local g = function(n) return ch:FindFirstChild(n) end
	if g("UpperTorso") then
		return { { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
			{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" }, { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
			{ "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" } }
	end
	return { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
end

local function espStep()
	local vs = Cam.ViewportSize
	local anyOn = F.esp_on or F.esp_tracers or F.cham_on
	local mouse = UIS:GetMouseLocation()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local o = ESP[plr]; if not o then o = espMake(); ESP[plr] = o end
			local ch, hum, hrp = validChar(plr)
			local show = anyOn and ch ~= nil and not (F.esp_team and sameTeam(plr))
			if not show then espHide(o)
			else
				local dist = (hrp.Position - Cam.CFrame.Position).Magnitude
				local col = playerCol(plr)
				local top = Cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.8, 0))
				local bot = Cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
				local on = top.Z > 0
				-- chams
				local chamsOn = F.cham_on and dist <= F.esp_max
				o.hl.Enabled = chamsOn
				if chamsOn then
					local style = F.cham_style
					local c = (F.team_colors and sameTeam(plr)) and getCol("col_team") or (F.cham_accent and T.accent or getCol("col_cham"))
					o.hl.Adornee = ch; o.hl.FillColor = c
					o.hl.FillTransparency = style == "Outline" and 1 or (style == "Fresnel" and 0.82 or (style == "Pulse" and 0.35 + 0.3 * math.sin(os.clock() * 3) or F.cham_fill))
					o.hl.OutlineColor = F.cham_outline and getCol("col_cham_out") or c
					o.hl.OutlineTransparency = style == "Fill" and 0.7 or 0
					o.hl.DepthMode = F.cham_vis and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
				end
				-- tracer
				if F.esp_tracers and on and dist <= F.tracer_max then
					local org = F.tracer_origin == "Center" and Vector2.new(vs.X / 2, vs.Y / 2) or (F.tracer_origin == "Top" and Vector2.new(vs.X / 2, 0) or (F.tracer_origin == "Mouse" and mouse or Vector2.new(vs.X / 2, vs.Y)))
					o.line.Visible = true; o.line.BackgroundColor3 = F.esp_on and col or getCol("col_tracer")
					line(o.line, org, Vector2.new(top.X, bot.Y), F.tracer_thick)
					if not F.esp_on then o.line.BackgroundColor3 = getCol("col_tracer") end
				else o.line.Visible = false end
				-- off-screen arrow
				local inView = on and top.X > 0 and top.X < vs.X and top.Y > 0 and top.Y < vs.Y
				if F.esp_on and F.esp_arrows and not inView and dist <= F.esp_max then
					local v = Cam.CFrame:PointToObjectSpace(hrp.Position)
					local dir = Vector2.new(v.X, -v.Y)
					if dir.Magnitude > 0.001 then
						dir = dir.Unit
						local pos = vs / 2 + dir * math.min(vs.X, vs.Y) * 0.4
						o.arrow.Visible = true; o.arrow.Position = UDim2.fromOffset(pos.X, pos.Y); o.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)); o.arrow.TextColor3 = col
					else o.arrow.Visible = false end
				else o.arrow.Visible = false end
				-- esp
				local espOn = F.esp_on and on and dist <= F.esp_max
				if not espOn then
					o.box.Visible = false; o.fill.Visible = false
					for _, c in ipairs(o.corners) do c.Visible = false end
					o.name.Visible, o.dist.Visible, o.hpbg.Visible, o.head.Visible = false, false, false, false
					for _, b in ipairs(o.bones) do b.Visible = false end
				else
					local h = math.abs(bot.Y - top.Y); local w = h * 0.55
					local x, y = top.X - w / 2, top.Y
					if F.esp_box and F.esp_boxstyle == "Corner" then
						o.box.Visible = false
						local l, th = math.max(6, math.min(w, h) * 0.25), 1.6
						local rects = { { x, y, l, th }, { x, y, th, l }, { x + w - l, y, l, th }, { x + w - th, y, th, l }, { x, y + h - th, l, th }, { x, y + h - l, th, l }, { x + w - l, y + h - th, l, th }, { x + w - th, y + h - l, th, l } }
						for i, c in ipairs(o.corners) do local r = rects[i]; c.Visible = true; c.BackgroundColor3 = col; c.Position = UDim2.fromOffset(r[1], r[2]); c.Size = UDim2.fromOffset(r[3], r[4]) end
					else
						for _, c in ipairs(o.corners) do c.Visible = false end
						o.box.Visible = F.esp_box and true or false
						o.box.Position = UDim2.fromOffset(x, y); o.box.Size = UDim2.fromOffset(w, h); o.stroke.Color = col
					end
					o.fill.Visible = F.esp_box and F.esp_fill; o.fill.BackgroundColor3 = col
					o.name.TextSize = F.esp_tsize; o.dist.TextSize = F.esp_tsize - 1
					local tool = F.esp_tool and ch:FindFirstChildOfClass("Tool")
					o.name.Visible = F.esp_name; o.name.Text = plr.DisplayName .. (tool and (" [" .. tool.Name .. "]") or ""); o.name.TextColor3 = col; o.name.Position = UDim2.fromOffset(top.X, y - 2)
					local dShown = F.esp_unit == "Meters" and (dist * 0.357) or dist
					o.dist.Visible = F.esp_dist or F.esp_hptext; o.dist.Text = (F.esp_dist and (math.floor(dShown) .. (F.esp_unit == "Meters" and " m" or " studs")) or "") .. ((F.esp_dist and F.esp_hptext) and "  ·  " or "") .. (F.esp_hptext and (math.floor(hum.Health) .. "hp") or ""); o.dist.Position = UDim2.fromOffset(top.X, bot.Y + 2)
					o.hpbg.Visible = F.esp_hp; o.hpbg.Position = UDim2.fromOffset(x - 6, y); o.hpbg.Size = UDim2.fromOffset(3, h)
					local a = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					o.hp.Size = UDim2.fromScale(1, a); o.hp.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 255, 120), a)
					-- head dot
					local head = ch:FindFirstChild("Head")
					if F.esp_head and head then
						local hp = Cam:WorldToViewportPoint(head.Position)
						o.head.Visible = hp.Z > 0; o.head.Position = UDim2.fromOffset(hp.X, hp.Y); o.head.BackgroundColor3 = col
					else o.head.Visible = false end
					-- skeleton
					if F.esp_skel then
						local pr = skelPairs(ch)
						for i, b in ipairs(o.bones) do
							local pa = pr[i]
							local A, B = pa and ch:FindFirstChild(pa[1]), pa and ch:FindFirstChild(pa[2])
							if A and B then
								local p1, p2 = Cam:WorldToViewportPoint(A.Position), Cam:WorldToViewportPoint(B.Position)
								b.Visible = p1.Z > 0 and p2.Z > 0
								if b.Visible then line(b, Vector2.new(p1.X, p1.Y), Vector2.new(p2.X, p2.Y), 1.5); b.BackgroundColor3 = col end
							else b.Visible = false end
						end
					else for _, b in ipairs(o.bones) do b.Visible = false end end
				end
			end
		end
	end
	-- self chams
	if not G.selfHL then G.selfHL = new("Highlight", { FillTransparency = 0.5, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = G.OV }) end
	local my = LP.Character
	G.selfHL.Enabled = F.cham_self and my ~= nil
	if G.selfHL.Enabled then G.selfHL.Adornee = my; G.selfHL.FillColor = getCol("col_self"); G.selfHL.OutlineColor = getCol("col_self") end
end

-- aimbot visuals
G.FOVC = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = G.OV }); rd(G.FOVC, 9999)
G.FOVS = stroke(G.FOVC, T.accent, 0.35, 1.5)
G.LockHL = new("Highlight", { FillTransparency = 0.55, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = G.OV })
onAccent(function(c) G.LockHL.FillColor = c; G.LockHL.OutlineColor = c end)
G.XH = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Visible = false, Parent = G.OV })
G.HM = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Visible = false, Parent = G.OV })
for i = 1, 4 do
	local f = ovf({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(i % 2 == 0 and 0.2 or 0.8, i <= 2 and 0.2 or 0.8), Size = UDim2.fromOffset(9, 2), Rotation = (i == 1 or i == 4) and 45 or -45, BackgroundColor3 = OVC, Parent = G.HM })
end
G.HUD = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.fromOffset(230, 58), BackgroundColor3 = Color3.fromRGB(9, 9, 12), BackgroundTransparency = 0.2, Visible = false, Parent = G.OV }); rd(G.HUD, 12); new("UIStroke", { Color = OVC, Transparency = 0.85, Parent = G.HUD })
G.HUDImg = new("ImageLabel", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.fromRGB(28, 28, 34), Parent = G.HUD }); rd(G.HUDImg, 21)
G.HUDName = new("TextLabel", { BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = OVC, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -66, 0, 16), Parent = G.HUD })
G.HUDSub = new("TextLabel", { BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(150, 152, 165), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(58, 24), Size = UDim2.new(1, -66, 0, 14), Parent = G.HUD })
G.HUDBg = new("Frame", { Position = UDim2.fromOffset(58, 42), Size = UDim2.new(1, -68, 0, 5), BackgroundColor3 = Color3.fromRGB(50, 50, 58), BorderSizePixel = 0, Parent = G.HUD }); rd(G.HUDBg, 3)
G.HUDHp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = G.HUDBg }); rd(G.HUDHp, 3)

-- chip (watermark + fps + ping)
G.Chip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(200, 28), BackgroundColor3 = Color3.fromRGB(9, 9, 12), BackgroundTransparency = 0.2, Parent = G.OV }); rd(G.Chip, 14); new("UIStroke", { Color = OVC, Transparency = 0.88, Parent = G.Chip })
G.ChipEye = makeLogo(G.Chip, 18, { Position = UDim2.fromOffset(8, 5) })
G.ChipL = new("TextLabel", { BackgroundTransparency = 1, Text = "ambience", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = OVC, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = G.Chip })

-- radar
G.Radar = new("Frame", { Position = UDim2.new(0, 14, 1, -150), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = Color3.fromRGB(9, 9, 12), BackgroundTransparency = 0.25, Visible = false, ClipsDescendants = true, Parent = G.OV }); rd(G.Radar, 60)
local radarStroke = stroke(G.Radar, T.accent, 0.4, 1.5); onAccent(function(c) radarStroke.Color = c end)
rd(ovf({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = OVC, Parent = G.Radar }), 3)
G.RadarDots = {}

-- touch quick pad
G.Pad = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 208), BackgroundTransparency = 1, Visible = false, Parent = G.OV })
new("UIListLayout", { Padding = UDim.new(0, 8), Parent = G.Pad })
for _, q in ipairs({ { "AIM", "aim_on" }, { "ESP", "esp_on" }, { "FLY", "fly_on" }, { "SL", "shiftlock" } }) do
	local b = new("TextButton", { Text = q[1], TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = OVC, Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.15, AutoButtonColor = false, Parent = G.Pad }); rd(b, 23)
	local st = stroke(b, T.accent, 0.4, 1.5); onAccent(function(c) st.Color = c end)
	conn(b.Activated, function() if UI[q[2]] then UI[q[2]](not F[q[2]]) end end)
end

-- waypoint markers
G.WPM = {}
local function wpStep()
	local n = 0
	if F.wp_markers then
		for _, w in ipairs(Waypoints) do
			local p = Cam:WorldToViewportPoint(w.cf.Position)
			if p.Z > 0 then
				n += 1
				local m = G.WPM[n]
				if not m then
					m = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = OVC, TextStrokeTransparency = 0.5, Size = UDim2.fromOffset(160, 28), AnchorPoint = Vector2.new(.5, .5), Parent = G.OV })
					G.WPM[n] = m
				end
				m.Visible = true; m.Position = UDim2.fromOffset(p.X, p.Y)
				m.Text = ("◆ %s\n%d studs"):format(w.name, (w.cf.Position - Cam.CFrame.Position).Magnitude)
			end
		end
	end
	for i = n + 1, #G.WPM do G.WPM[i].Visible = false end
end

----------------------------------------------------------------------
-- AIMBOT
----------------------------------------------------------------------
G.locked = nil
function G.spawnHit(pos)
	local p = Cam:WorldToViewportPoint(pos)
	if p.Z <= 0 then return end
	for i = 1, 9 do
		local f = ovf({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = T.accent, Parent = G.OV }); rd(f, 2)
		local a = math.random() * math.pi * 2; local r = math.random(18, 46)
		tw(f, 0.45, { Position = UDim2.fromOffset(p.X + math.cos(a) * r, p.Y + math.sin(a) * r), BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) })
		task.delay(0.5, function() f:Destroy() end)
	end
end
local function aimPart(ch)
	local n = F.aim_part
	if n == "Head" then return ch:FindFirstChild("Head") end
	if n == "Torso" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch:FindFirstChild("HumanoidRootPart") end
	return ch:FindFirstChild("HumanoidRootPart")
end
local function visibleRaw(part, ch)
	local ignore = { LP.Character, ch, Cam }
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
	local o = Cam.CFrame.Position
	for _ = 1, 5 do
		rp.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(o, part.Position - o, rp)
		if not hit then return true end
		local p = hit.Instance
		if p.CanCollide == false or p.Transparency > 0.9 then ignore[#ignore + 1] = p else return false end
	end
	return false
end
local function visibleTo(part, ch)
	local prev = G.noHook; G.noHook = true
	local ok, r = pcall(visibleRaw, part, ch)
	G.noHook = prev
	return ok and r or false
end
local function aimStep()
	local nowT = os.clock(); G.aimDt = nowT - (G.aimLast or nowT); G.aimLast = nowT
	local vs = Cam.ViewportSize
	local org = UIS.MouseEnabled and UIS:GetMouseLocation() or (vs / 2)
	local active = F.aim_on and (not F.aim_rmb or not UIS.MouseEnabled or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
	G.aimActive = active
	G.FOVC.Visible = F.aim_on and F.aim_circle
	G.FOVC.Size = UDim2.fromOffset(F.aim_fov * 2, F.aim_fov * 2); G.FOVC.Position = UDim2.fromOffset(org.X, org.Y); G.FOVS.Color = getCol("col_fov")
	G.XH.Visible = F.crosshair
	if F.crosshair then drawCross(G.XH, F.cross_style, F.cross_size, F.cross_gap, F.cross_thick, getCol("col_cross")); G.XH.Position = UDim2.fromOffset(vs.X / 2, vs.Y / 2) end
	local locked = G.locked
	if not active then G.locked = nil
	else
		local keep = false
		if locked and F.aim_sticky then local ch = validChar(locked); keep = ch ~= nil end
		if not keep then
			local best, bs = nil, math.huge
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP and not (F.aim_team and sameTeam(plr)) and not (F.aim_friends and Friends[plr.UserId]) then
					local ch, hum, hrp = validChar(plr)
					if ch then
						local part = aimPart(ch)
						if part then
							local d3 = (part.Position - Cam.CFrame.Position).Magnitude
							local sp, on = Cam:WorldToViewportPoint(part.Position)
							local d2 = (Vector2.new(sp.X, sp.Y) - org).Magnitude
							if on and d3 <= F.aim_max and d2 <= F.aim_fov and (not F.aim_wall or visibleTo(part, ch)) then
								local score = d2
								if F.aim_prio == "Distance" then score = d3 elseif F.aim_prio == "Lowest HP" then score = hum.Health end
								if score < bs then best, bs = plr, score end
							end
						end
					end
				end
			end
			G.locked = best
		end
		if G.locked then
			local ch = validChar(G.locked)
			local part = ch and aimPart(ch)
			if part then
				local pos = part.Position + part.AssemblyLinearVelocity * F.aim_pred
				local base = math.clamp((100 - F.aim_smooth) / 100, 0.03, 1)
				local alpha = 1 - (1 - base) ^ (math.min(G.aimDt or 0.016, 0.05) * 60)
				if F.aim_mode == "Mouse" then
					local sp = Cam:WorldToViewportPoint(pos)
					pcall(function() mousemoverel((sp.X - org.X) * alpha, (sp.Y - org.Y) * alpha) end)
				else
					Cam.CFrame = Cam.CFrame:Lerp(CFrame.lookAt(Cam.CFrame.Position, pos), alpha)
				end
			end
		end
	end
	if G.locked then G.lastLocked = G.locked; G.lastLockT = os.clock() end
	local ch, hum, hrp
	if G.locked then ch, hum, hrp = validChar(G.locked) end
	G.LockHL.Enabled = ch ~= nil and F.aim_hl
	if ch then G.LockHL.Adornee = ch end
	G.HUD.Visible = ch ~= nil and F.aim_hud
	if ch then
		G.HUDName.Text = G.locked.DisplayName
		G.HUDImg.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(G.locked.UserId)
		G.HUDSub.Text = ("%d studs  ·  %s"):format(math.floor((hrp.Position - Cam.CFrame.Position).Magnitude), F.aim_part == "Head" and "Headshot" or F.aim_part)
		local a = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		G.HUDHp.Size = UDim2.fromScale(a, 1); G.HUDHp.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 255, 120), a)
		if F.hitmarker then
			if G.lastHp and hum.Health < G.lastHp - 0.5 then G.hitT = os.clock(); G.hitChamT = os.clock(); if F.hit_particles then G.spawnHit(hrp.Position) end end
			G.lastHp = hum.Health
		end
	else G.lastHp = nil end
	if ch and F.hit_chams and G.hitChamT and os.clock() - G.hitChamT < 0.25 then G.LockHL.Enabled = true; G.LockHL.FillTransparency = 0.1; G.LockHL.FillColor = OVC
	elseif ch then G.LockHL.FillTransparency = 0.55; G.LockHL.FillColor = T.accent end
	G.HM.Visible = G.hitT ~= nil and os.clock() - G.hitT < 0.25
	if G.HM.Visible then G.HM.Position = UDim2.fromOffset(vs.X / 2, vs.Y / 2) end
end

-- active features list (top-right)
G.AL = {}
G.alT = 0
local function alStep(t)
	if t - G.alT < 0.15 then return end
	G.alT = t
	local on = {}
	for _, d in ipairs({ { "Aimbot", F.aim_on }, { "Silent aim", F.silent_on }, { "Shiftlock", F.shiftlock }, { "ESP", F.esp_on }, { "Chams", F.cham_on }, { "Tracers", F.esp_tracers }, { "Fly", F.fly_on }, { "Noclip", F.noclip }, { "Speed", F.speed_on }, { "Hitbox", F.hb_on }, { "Triggerbot", F.trig_on }, { "Fullbright", F.fullbright }, { "Anti-void", F.antivoid } }) do
		if d[2] and F.arraylist then on[#on + 1] = d[1] end
	end
	table.sort(on, function(a, b) return #a > #b end)
	for i = 1, math.max(#on, #G.AL) do
		local l = G.AL[i]
		if not l and on[i] then
			l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(160, 16), TextStrokeTransparency = 0.6, Parent = G.OV })
			G.AL[i] = l
		end
		if l then
			if on[i] then l.Visible = true; l.Text = on[i]; l.Position = UDim2.new(1, -10, 0, 44 + (i - 1) * 16); l.TextColor3 = T.accent else l.Visible = false end
		end
	end
end

----------------------------------------------------------------------
-- SILENT AIM  (circle follows your hand / cursor; shots get rerouted to the target inside it)
----------------------------------------------------------------------
G.SAC = new("Frame", { AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1, Visible = false, Parent = G.OV }); rd(G.SAC, 9999)
G.SACS = stroke(G.SAC, T.accent, 0.15, 1.8)
G.SAL = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = OVC, TextStrokeTransparency = 0.5, Size = UDim2.fromOffset(220, 14), AnchorPoint = Vector2.new(.5, 0), Visible = false, Parent = G.OV })
G.SAD = ovf({ AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = T.accent, Visible = false, Parent = G.OV }); rd(G.SAD, 4)
G.SAT = ovf({ AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = T.accent, BackgroundTransparency = 0.4, Visible = false, Parent = G.OV })
G.saPart, G.saPos, G.saTarget = nil, nil, nil
G.saRoll, G.saRollT, G.firing = true, 0, false
G.camPos = Cam.CFrame.Position
G.mouse = LP:GetMouse()

local function saOrigin()
	local vs = Cam.ViewportSize
	if F.silent_origin == "Hand" then
		local ch = LP.Character
		if ch then
			local tool = ch:FindFirstChildOfClass("Tool")
			local hp = (tool and tool:FindFirstChild("Handle")) or ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")
			if hp then local p = Cam:WorldToViewportPoint(hp.Position); if p.Z > 0 then return Vector2.new(p.X, p.Y) end end
		end
	elseif F.silent_origin == "Cursor" and UIS.MouseEnabled then return UIS:GetMouseLocation() end
	return vs / 2
end
local function saPartOf(ch)
	local n = F.sa_part
	if n == "Random" then
		if os.clock() - (G.saRandT or 0) > 0.3 then G.saRandT = os.clock(); G.saRandPick = ({ "Head", "Torso", "Root" })[math.random(1, 3)] end
		n = G.saRandPick or "Head"
	end
	if n == "Head" then return ch:FindFirstChild("Head") end
	if n == "Torso" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch:FindFirstChild("HumanoidRootPart") end
	return ch:FindFirstChild("HumanoidRootPart")
end
local function saStep()
	G.camPos = Cam.CFrame.Position
	G.SAC.Visible = F.silent_on and F.silent_circle
	if not F.silent_on then G.saTarget, G.saPart, G.saPos = nil, nil, nil; G.SAL.Visible = false; G.SAD.Visible = false; G.SAT.Visible = false; return end
	local org = saOrigin()
	G.SAC.Size = UDim2.fromOffset(F.silent_fov * 2, F.silent_fov * 2); G.SAC.Position = UDim2.fromOffset(org.X, org.Y); G.SACS.Color = getCol("col_sa")
	if G.firing and os.clock() - G.saRollT > 0.12 then G.saRoll = math.random(1, 100) <= F.sa_hit; G.saRollT = os.clock() end
	local best, bp, bs
	bs = math.huge
	local prev = G.noHook; G.noHook = true
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and not (F.sa_team and sameTeam(plr)) and not (F.aim_friends and Friends[plr.UserId]) then
			local ch = validChar(plr)
			if ch then
				local part = saPartOf(ch)
				if part then
					local sp, on = Cam:WorldToViewportPoint(part.Position)
					local d2 = (Vector2.new(sp.X, sp.Y) - org).Magnitude
					if on and d2 <= F.silent_fov and d2 < bs and (not F.sa_wall or visibleTo(part, ch)) then best, bp, bs = plr, part, d2 end
				end
			end
		end
	end
	G.noHook = prev
	G.saTarget, G.saPart = best, bp
	if bp then G.saPos = bp.Position + bp.AssemblyLinearVelocity * F.sa_pred else G.saPos = nil end
	local show = best ~= nil and F.silent_circle
	G.SAL.Visible = show; G.SAD.Visible = show; G.SAT.Visible = show
	if show then
		local sp = Cam:WorldToViewportPoint(G.saPos)
		G.SAD.Position = UDim2.fromOffset(sp.X, sp.Y); G.SAD.BackgroundColor3 = getCol("col_sa")
		line(G.SAT, org, Vector2.new(sp.X, sp.Y), 1); G.SAT.BackgroundColor3 = getCol("col_sa")
		G.SAL.Position = UDim2.fromOffset(org.X, org.Y + F.silent_fov + 4); G.SAL.Text = "◎ " .. best.DisplayName
	end
end

local function saActive()
	if not alive or not F.silent_on or G.noHook or not G.saPos or not G.saRoll then return false end
	if G.isOpen then return false end
	if F.sa_shoot_only and not G.firing then return false end
	if F.sa_tool_only then local ch = LP.Character; if not (ch and ch:FindFirstChildOfClass("Tool")) then return false end end
	if checkcaller and checkcaller() then return false end
	return true
end
genv.__AmbienceSilentInstall = function()
	if G.saHooked then return true end
	if not hookmetamethod then return false end
	local ok = pcall(function()
		local oldNC, oldIdx
		local nc = function(self, ...)
			local m = getnamecallmethod()
			if F.sa_ray and (m == "Raycast" or m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist" or m == "ViewportPointToRay" or m == "ScreenPointToRay") and saActive() then
				local n = select("#", ...)
				local args = { ... }
				local pos = G.saPos
				if m == "Raycast" and self == workspace then
					local o, d = args[1], args[2]
					if typeof(o) == "Vector3" and typeof(d) == "Vector3" then
						args[2] = (pos - o).Unit * math.max(d.Magnitude, (pos - o).Magnitude + 5)
						return oldNC(self, table.unpack(args, 1, n))
					end
				elseif m:sub(1, 11) == "FindPartOnR" and self == workspace then
					local r = args[1]
					if typeof(r) == "Ray" then
						args[1] = Ray.new(r.Origin, (pos - r.Origin).Unit * math.max(r.Direction.Magnitude, (pos - r.Origin).Magnitude + 5))
						return oldNC(self, table.unpack(args, 1, n))
					end
				elseif F.sa_camray and self == Cam then
					local r = oldNC(self, ...)
					return Ray.new(r.Origin, (pos - r.Origin).Unit)
				end
			end
			return oldNC(self, ...)
		end
		G.saOk1 = pcall(function() oldNC = hookmetamethod(game, "__namecall", newcclosure and newcclosure(nc) or nc) end)
		local idx = function(self, k)
			if (k == "Hit" or k == "Target" or k == "UnitRay") and F.sa_mouse and self == G.mouse and saActive() then
				if k == "Hit" then return CFrame.new(G.saPos) end
				if k == "Target" then return G.saPart end
				return Ray.new(G.camPos, (G.saPos - G.camPos).Unit)
			end
			return oldIdx(self, k)
		end
		G.saOk2 = pcall(function() oldIdx = hookmetamethod(game, "__index", newcclosure and newcclosure(idx) or idx) end)
	end)
	G.saHooked = ok and (G.saOk1 or G.saOk2) and true or false
	return G.saHooked
end

----------------------------------------------------------------------
-- SHIFTLOCK (PC-style: locked mouse, over-the-shoulder camera, character follows camera)
----------------------------------------------------------------------
G.SLC = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = T.accent, Visible = false, Parent = G.OV }); rd(G.SLC, 3)
new("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 0.5, Parent = G.SLC })
onAccent(function(c) G.SLC.BackgroundColor3 = c end)
local function slRestore()
	if not G.slOn then return end
	G.slOn = false
	local _, hum = (function() local ch = LP.Character; return ch, ch and ch:FindFirstChildOfClass("Humanoid") end)()
	if hum then
		hum.AutoRotate = G.slAR == nil and true or G.slAR
		hum.CameraOffset = G.slOff or Vector3.zero
	end
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true end)
end
G.slRestore = slRestore
local function shiftStep(dt)
	local ch = LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local want = F.shiftlock and not G.isOpen and hum and hrp and hum.Health > 0
	if want then
		if not G.slOn then G.slOn = true; G.slAR = hum.AutoRotate; G.slOff = hum.CameraOffset end
		if UIS.MouseEnabled then pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCenter; UIS.MouseIconEnabled = false end) end
		hum.AutoRotate = false
		hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.new(F.sl_offset, 0, 0), math.clamp(dt * 12, 0, 1))
		if not hum.Sit then
			local look = Cam.CFrame.LookVector
			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		end
		G.SLC.Visible = F.sl_cross
	else
		slRestore()
		G.SLC.Visible = false
	end
end

----------------------------------------------------------------------
-- AVATAR STUDIO  (opens from the profile button) — catalog-creator style
--   rail of categories · searchable item grid · wear / take off · per-slot animation builder
--   body-part bundles (head / torso / each arm / each leg) · skin · scale · R6 look · outfits
-- Everything is client-side: you see it, other players don't.
----------------------------------------------------------------------
;(function()
local AV = {}
G.AV = AV
local AES, InsertService = nil, svc("InsertService")
pcall(function() AES = svc("AvatarEditorService") end)
AV.worn = {}        -- [instance] = assetId (items added through the studio)
AV.descIds = {}     -- [assetId] = category key (items applied through HumanoidDescription)
AV.removed = {}     -- undo stack
AV.nameToId = {}
AV.rig, AV.tabName = "Live", "Catalog"
AV.spin = 0
AV.buildIds, AV.buildNames = {}, {}

AV.root = new("Frame", { Name = "AvatarStudio", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Pal.Dark.win, BackgroundTransparency = 0.03, Active = true, Visible = false, Parent = G.Win })
skin(AV.root, "win")

----------------------------------------------------------------------
-- left: live preview
----------------------------------------------------------------------
AV.left = new("Frame", { Size = UDim2.new(0, 236, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = AV.root })
local ttl = label(AV.left, "Avatar Studio", 18, T.text, Enum.Font.GothamBold); ttl.Position = UDim2.fromOffset(16, 12); ttl.Size = UDim2.new(1, -32, 0, 24)
local sub = label(AV.left, "@" .. LP.Name .. "  ·  client-side", 10, T.sub, Enum.Font.Gotham); sub.Position = UDim2.fromOffset(17, 36); sub.Size = UDim2.new(1, -32, 0, 12)
AV.stage = new("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 250), BackgroundColor3 = Color3.fromRGB(6, 6, 9), BackgroundTransparency = 0.1, ClipsDescendants = true, Parent = AV.left }); rd(AV.stage, 14)
AV.glow = new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 276, 276), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(.9, .95), ImageTransparency = 0.55, Parent = AV.stage })
onAccent(function(c) AV.glow.ImageColor3 = c end)
AV.vp = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(170, 170, 185), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -0.7, 0.6), Parent = AV.stage })
AV.cam = new("Camera", { FieldOfView = 34, Parent = AV.vp }); AV.vp.CurrentCamera = AV.cam
AV.status = label(AV.stage, "Loading preview…", 11, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Center); AV.status.Size = UDim2.fromScale(1, 1)
AV.rigBtns = {}
for i, r in ipairs({ "Live", "R15", "R6" }) do
	local b = new("TextButton", { Text = r, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Position = UDim2.fromOffset(12 + (i - 1) * 70, 314), Size = UDim2.fromOffset(64, 26), AutoButtonColor = false, Parent = AV.left }); rd(b, 9)
	AV.rigBtns[r] = b
	conn(b.Activated, function() AV.rig = r; AV.paintRig(); AV.buildPreview() end)
end
function AV.paintRig()
	for r, b in pairs(AV.rigBtns) do tw(b, 0.2, { BackgroundTransparency = AV.rig == r and 0.6 or 0.92, BackgroundColor3 = AV.rig == r and T.accent or WHITE }) end
end
onAccent(function() AV.paintRig() end)
AV.info = label(AV.left, "", 11, T.sub, Enum.Font.Gotham); AV.info.Position = UDim2.fromOffset(16, 348); AV.info.Size = UDim2.new(1, -32, 0, 40); AV.info.TextWrapped = true; AV.info.TextYAlignment = Enum.TextYAlignment.Top
AV.refreshBtn = new("TextButton", { Text = "Refresh preview", TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = T.accent, BackgroundTransparency = 0.7, Position = UDim2.new(0, 12, 1, -44), Size = UDim2.new(1, -24, 0, 32), AutoButtonColor = false, Parent = AV.left }); rd(AV.refreshBtn, 10)
onAccent(function(c) AV.refreshBtn.BackgroundColor3 = c end)
conn(AV.refreshBtn.Activated, function() AV.buildPreview() end)

function AV.clearModel() if AV.model then AV.model:Destroy(); AV.model = nil end end
function AV.buildPreview()
	AV.token = (AV.token or 0) + 1
	local tok = AV.token
	AV.status.Visible = true; AV.status.Text = "Loading preview…"
	task.spawn(function()
		local model
		if AV.rig == "Live" then
			local ch = LP.Character
			if ch then
				local old = ch.Archivable; ch.Archivable = true
				local ok, c = pcall(function() return ch:Clone() end)
				ch.Archivable = old
				if ok then model = c end
			end
		else
			local ok, m = pcall(function()
				local desc = Players:GetHumanoidDescriptionFromUserId(LP.UserId)
				return Players:CreateHumanoidModelFromDescription(desc, AV.rig == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15)
			end)
			if ok and m then
				model = m
				local hum = m:FindFirstChildOfClass("Humanoid")
				for inst in pairs(AV.worn) do
					if inst.Parent and inst:IsA("Accessory") and hum then pcall(function() hum:AddAccessory(inst:Clone()) end) end
				end
			end
		end
		if tok ~= AV.token then if model then model:Destroy() end return end
		if not model then AV.status.Text = "Preview unavailable"; return end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true end
		end
		AV.clearModel()
		model.Parent = AV.vp; AV.model = model
		pcall(function() model:PivotTo(CFrame.new(0, 0, 0)) end)
		local ok2, cf, size = pcall(function() return model:GetBoundingBox() end)
		if ok2 then
			AV.center = cf.Position
			AV.dist = math.max(size.Y, size.X * 1.1) / (2 * math.tan(math.rad(AV.cam.FieldOfView / 2))) * 1.18
		end
		AV.status.Visible = false
	end)
end
function AV.schedule()
	AV.sched = (AV.sched or 0) + 1
	local id = AV.sched
	task.delay(0.6, function() if id == AV.sched and AV.root.Visible then AV.buildPreview() end end)
end
conn(RS.RenderStepped, function(dt)
	if not AV.root.Visible or not AV.model or not AV.center then return end
	AV.spin += dt * 0.8
	pcall(function() AV.model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, AV.spin, 0)) end)
	AV.cam.CFrame = CFrame.lookAt(AV.center + Vector3.new(0, 0.1, -AV.dist), AV.center)
end)

----------------------------------------------------------------------
-- right: tabs + pages
----------------------------------------------------------------------
AV.right = new("Frame", { Position = UDim2.fromOffset(236, 0), Size = UDim2.new(1, -236, 1, 0), BackgroundTransparency = 1, Parent = AV.root })
AV.pages, AV.tabBtns = {}, {}
local tabs = { "Catalog", "Animations", "Wearing", "Bundles", "Body", "Outfits" }
local plainTabs = { Catalog = true, Animations = true }
function AV.selectTab(n)
	AV.tabName = n
	for k, pg in pairs(AV.pages) do pg.Visible = (k == n) end
	for k, b in pairs(AV.tabBtns) do
		local on = k == n
		tw(b, 0.2, { BackgroundTransparency = on and 0.6 or 0.94, BackgroundColor3 = on and T.accent or WHITE })
		b.TextColor3 = on and WHITE or Pal[S.mode].sub
	end
	if n == "Wearing" and AV.refreshWorn then AV.refreshWorn() end
end
do
	local x = 12
	for _, n in ipairs(tabs) do
		local w = #n * 7 + 24
		local b = new("TextButton", { Text = n, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Position = UDim2.fromOffset(x, 12), Size = UDim2.fromOffset(w, 30), AutoButtonColor = false, Parent = AV.right }); rd(b, 15)
		AV.tabBtns[n] = b; x += w + 5
		conn(b.Activated, function() AV.selectTab(n) end)
		local pg
		if plainTabs[n] then
			pg = new("Frame", { Name = n, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -62), Visible = false, Parent = AV.right })
		else
			pg = new("ScrollingFrame", { Name = n, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -62), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE, Visible = false, Parent = AV.right })
			new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pg })
			new("UIPadding", { PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), Parent = pg })
		end
		AV.pages[n] = pg
	end
end
AV.closeBtn = new("TextButton", { Text = "×", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(30, 30), AutoButtonColor = false, Parent = AV.right }); rd(AV.closeBtn, 15)
conn(AV.closeBtn.Activated, function() AV.close() end)
function AV.open()
	AV.root.Visible = true
	AV.root.Position = UDim2.fromScale(0, 0.05); tw(AV.root, 0.45, { Position = UDim2.fromScale(0, 0) })
	AV.paintRig(); AV.selectTab(AV.tabName); AV.buildPreview(); AV.loadAppearance()
end
function AV.close() AV.root.Visible = false; AV.clearModel() end
conn(G.AccBtn.Activated, function() AV.open() end)

----------------------------------------------------------------------
-- helpers: char, http, loading, attaching, take-off
----------------------------------------------------------------------
local function myChar() local ch = LP.Character; return ch, ch and ch:FindFirstChildOfClass("Humanoid") end
local function httpGet(url)
	local req = (request or http_request or (syn and syn.request) or (http and http.request))
	if not req then return nil end
	local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
	if ok and res and (res.StatusCode == 200 or res.Success) then return res.Body end
end
function AV.loadAppearance()
	if AV.appLoaded then return end
	AV.appLoaded = true
	task.spawn(function()
		local ok, info = pcall(function() return Players:GetCharacterAppearanceInfoAsync(LP.UserId) end)
		if ok and info and info.assets then
			for _, a in ipairs(info.assets) do AV.nameToId[a.name] = a.id end
			if AV.refreshWorn then AV.refreshWorn() end
		end
	end)
end

local BODY_NAMES = { Head = true, UpperTorso = true, LowerTorso = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
local function loadAsset(id)
	local why = "no loader"
	if game.GetObjects then
		local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
		if ok and res and res[1] then return res[1] end
		why = ok and "empty result" or tostring(res)
	end
	local ok2, m = pcall(function() return InsertService:LoadAsset(id) end)
	if ok2 and m then return m end
	return nil, why
end

-- weld an accessory to the character by attachment name (fallback when the engine doesn't do it)
local function manualWeld(ch, acc)
	local handle = acc:FindFirstChild("Handle"); if not handle then return false end
	if handle:FindFirstChild("AccessoryWeld") then return true end
	local att = handle:FindFirstChildOfClass("Attachment")
	if att then
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("Attachment") and d.Name == att.Name and d.Parent:IsA("BasePart") and not d:IsDescendantOf(acc) and d.Parent.Parent == ch then
				local w = Instance.new("Weld"); w.Name = "AccessoryWeld"; w.Part0 = handle; w.Part1 = d.Parent; w.C0 = att.CFrame; w.C1 = d.CFrame; w.Parent = handle
				return true
			end
		end
	end
	local head = ch:FindFirstChild("Head")
	if head then
		local w = Instance.new("Weld"); w.Name = "AccessoryWeld"; w.Part0 = head; w.Part1 = handle
		w.C0 = CFrame.new(0, head.Size.Y / 2, 0) * acc.AttachmentPoint:Inverse(); w.Parent = handle
		return true
	end
	return false
end
local function equipAccessory(ch, hum, acc)
	acc.Parent = nil
	local ok = pcall(function() hum:AddAccessory(acc) end)
	if not ok or not acc.Parent then acc.Parent = ch end
	task.wait(0.12)
	pcall(manualWeld, ch, acc)
end

function AV.attach(obj, id)
	local ch, hum = myChar(); if not hum then return 0 end
	local n = 0
	local function add(o)
		if o:IsA("Accessory") then
			local c = o:Clone(); equipAccessory(ch, hum, c); AV.worn[c] = id; n += 1
		elseif o:IsA("Shirt") or o:IsA("Pants") or o:IsA("ShirtGraphic") then
			local ex = ch:FindFirstChildOfClass(o.ClassName); if ex then ex:Destroy() end
			local c = o:Clone(); c.Parent = ch; AV.worn[c] = id; n += 1
		elseif o:IsA("Decal") then
			local head = ch:FindFirstChild("Head"); local face = head and head:FindFirstChild("face")
			if face and face:IsA("Decal") then face.Texture = o.Texture; n += 1 end
		elseif o:IsA("MeshPart") and BODY_NAMES[o.Name] then
			local part = ch:FindFirstChild(o.Name)
			if part and part:IsA("MeshPart") then
				if not part:GetAttribute("AmbMesh") then part:SetAttribute("AmbMesh", part.MeshId); part:SetAttribute("AmbTex", part.TextureID) end
				part.MeshId = o.MeshId; if o.TextureID ~= "" then part.TextureID = o.TextureID end; n += 1
			end
		elseif o:IsA("SpecialMesh") and o.Parent and o.Parent.Name == "Head" then
			local head = ch:FindFirstChild("Head"); local sm = head and head:FindFirstChildOfClass("SpecialMesh")
			if sm then sm.MeshId = o.MeshId; sm.TextureId = o.TextureId; n += 1 end
		end
	end
	if obj:IsA("Accessory") or obj:IsA("Clothing") or obj:IsA("ShirtGraphic") or obj:IsA("Decal") then add(obj)
	else for _, d in ipairs(obj:GetDescendants()) do add(d) end end
	return n
end

-- HumanoidDescription fallback (used when the loader can't fetch the asset)
local DescProp = { Hat = "HatAccessory", HairAccessory = "HairAccessory", FaceAccessory = "FaceAccessory", NeckAccessory = "NeckAccessory", ShoulderAccessory = "ShoulderAccessory", FrontAccessory = "FrontAccessory", BackAccessory = "BackAccessory", WaistAccessory = "WaistAccessory", Shirt = "Shirt", Pants = "Pants", TShirt = "GraphicTShirt", Head = "Head", Face = "Face", Torso = "Torso", LeftArm = "LeftArm", RightArm = "RightArm", LeftLeg = "LeftLeg", RightLeg = "RightLeg" }
local ListProps = { HatAccessory = true, HairAccessory = true, FaceAccessory = true, NeckAccessory = true, ShoulderAccessory = true, FrontAccessory = true, BackAccessory = true, WaistAccessory = true }
local function viaDescription(id, cat, remove)
	local prop = DescProp[cat or ""]; if not prop then return false end
	local ch, hum = myChar(); if not hum then return false end
	local ok = pcall(function()
		local desc = hum:GetAppliedDescription()
		if ListProps[prop] then
			local list = {}
			for s in tostring(desc[prop]):gmatch("%d+") do if tonumber(s) ~= id then list[#list + 1] = s end end
			if not remove then list[#list + 1] = tostring(id) end
			desc[prop] = table.concat(list, ",")
		else desc[prop] = remove and 0 or id end
		hum:ApplyDescription(desc)
	end)
	return ok
end

function AV.wearAsset(id, name, cat)
	task.spawn(function()
		local ch, hum = myChar(); if not hum then notify("No character yet"); return end
		local obj, why = loadAsset(id)
		local n = obj and AV.attach(obj, id) or 0
		if n == 0 then
			if viaDescription(id, cat) then AV.descIds[id] = cat; n = 1
			else notify(obj and "That item type can't be applied here" or ("Couldn't load item (" .. tostring(why):sub(1, 30) .. ")")); return end
		end
		notify("Wearing · " .. (name or id))
		if AV.refreshWorn then AV.refreshWorn() end
		AV.schedule()
		if AV.paintResults then AV.paintResults() end
	end)
end
function AV.isWorn(id)
	for inst, i in pairs(AV.worn) do if i == id and inst.Parent then return inst end end
	if AV.descIds[id] then return "desc" end
end
function AV.takeOffId(id)
	local w = AV.isWorn(id)
	if w == "desc" then viaDescription(id, AV.descIds[id], true); AV.descIds[id] = nil; notify("Taken off")
	elseif w then AV.takeOff(w) end
	if AV.refreshWorn then AV.refreshWorn() end; AV.schedule()
	if AV.paintResults then AV.paintResults() end
end
function AV.takeOff(inst)
	if not inst or not inst.Parent then return end
	AV.removed[#AV.removed + 1] = { inst = inst, parent = inst.Parent }
	inst.Parent = nil
	if AV.refreshWorn then AV.refreshWorn() end; AV.schedule()
	if AV.paintResults then AV.paintResults() end
end
function AV.undo()
	local r = table.remove(AV.removed); if not r then notify("Nothing to put back"); return end
	local ch, hum = myChar(); if not ch then return end
	if r.inst:IsA("Accessory") and hum then hum:AddAccessory(r.inst) else r.inst.Parent = ch end
	notify("Put back · " .. r.inst.Name); AV.refreshWorn(); AV.schedule()
end

----------------------------------------------------------------------
-- category rail builder (used by Catalog + Animations)
----------------------------------------------------------------------
local function buildRail(parent, groups, onPick)
	local R = { btns = {} }
	local sf = new("ScrollingFrame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, Size = UDim2.new(0, 124, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE, Parent = parent })
	rd(sf, 12); stroke(sf, WHITE, 0.93)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = sf })
	local order = 0
	for _, g in ipairs(groups) do
		if g.hdr then order += 1; local h = label(sf, g.hdr, 9, T.sub, Enum.Font.GothamBold); h.Size = UDim2.new(1, 0, 0, 20); h.LayoutOrder = order; h.TextYAlignment = Enum.TextYAlignment.Bottom end
		for _, it in ipairs(g.items) do
			order += 1
			local b = new("TextButton", { Text = "", BackgroundColor3 = T.accent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, it.sub and 36 or 28), AutoButtonColor = false, LayoutOrder = order, Parent = sf }); rd(b, 8)
			local l = label(b, it.label, 12, T.text); l.Position = UDim2.fromOffset(8, it.sub and 3 or 0); l.Size = UDim2.new(1, -12, 0, it.sub and 16 or 28)
			local sl
			if it.sub then sl = label(b, it.sub, 9, T.sub, Enum.Font.Gotham); sl.Position = UDim2.fromOffset(8, 19); sl.Size = UDim2.new(1, -12, 0, 12); sl.TextTruncate = Enum.TextTruncate.AtEnd end
			R.btns[it.key] = { b = b, sub = sl }
			conn(b.Activated, function() R.select(it.key) end)
		end
	end
	function R.select(key, silent)
		R.cur = key
		for k, e in pairs(R.btns) do tw(e.b, 0.2, { BackgroundTransparency = k == key and 0.72 or 1 }) end
		if onPick and not silent then onPick(key) end
	end
	function R.setSub(key, text) local e = R.btns[key]; if e and e.sub then e.sub.Text = text end end
	onAccent(function(c) for _, e in pairs(R.btns) do e.b.BackgroundColor3 = c end end)
	return R
end

-- shared catalog search + item cards (catalog tab and animation tab)
local function searchPages(keyword, typeNames, bundleKind, sort, offsale)
	if not AES then return nil, "AvatarEditorService unavailable" end
	local p = CatalogSearchParams.new()
	p.SearchKeyword = keyword or ""
	pcall(function() p.SortType = Enum.CatalogSortType[sort or "Relevance"] end)
	pcall(function() p.IncludeOffSale = offsale and true or false end)
	if bundleKind then
		pcall(function() p.BundleTypes = { bundleKind == "anim" and Enum.BundleType.Animations or Enum.BundleType.BodyParts } end)
	else
		local types = {}
		for _, n in ipairs(typeNames or {}) do local ok, e = pcall(function() return Enum.AvatarAssetType[n] end); if ok and e then types[#types + 1] = e end end
		if #types > 0 then p.AssetTypes = types end
	end
	local ok, pages = pcall(function() return AES:SearchCatalog(p) end)
	if not ok then return nil, tostring(pages) end
	return pages
end
local function fetchNames(cards, isBundle)
	if not AES then return end
	task.spawn(function()
		local ids, byId = {}, {}
		for _, c in ipairs(cards) do if not c.named then ids[#ids + 1] = c.id; byId[c.id] = c end end
		if #ids == 0 then return end
		local ok, res = pcall(function() return AES:GetBatchItemDetails(ids, isBundle and Enum.AvatarItemType.Bundle or Enum.AvatarItemType.Asset) end)
		if ok and res then
			for _, d in ipairs(res) do
				local c = byId[d.Id]
				if c then
					c.name.Text = d.Name or c.name.Text
					if d.Price ~= nil then c.price.Text = (d.Price == 0 and "Free" or ("R$ " .. tostring(d.Price))) end
				end
			end
		end
	end)
end
local function makeCard(parent, item, order, onClick)
	local id = item.Id
	local isBundle = tostring(item.ItemType):find("Bundle") ~= nil
	local b = new("TextButton", { Text = "", BackgroundColor3 = Color3.fromRGB(18, 18, 24), AutoButtonColor = false, ClipsDescendants = true, LayoutOrder = order, Parent = parent }); rd(b, 12)
	local st = new("UIStroke", { Thickness = 1.5, Color = T.accent, Transparency = 0.85, Parent = b }); onAccent(function(c) st.Color = c end)
	new("ImageLabel", { BackgroundTransparency = 1, Image = isBundle and ("rbxthumb://type=BundleThumbnail&id=%d&w=150&h=150"):format(id) or ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(id), Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 96), ScaleType = Enum.ScaleType.Fit, Parent = b })
	local nm = new("TextLabel", { BackgroundTransparency = 1, Text = item.Name or ("Item " .. id), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = WHITE, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 28), Parent = b })
	local pr = (item.Price ~= nil) and (item.Price == 0 and "Free" or ("R$ " .. tostring(item.Price))) or ""
	local price = new("TextLabel", { BackgroundTransparency = 1, Text = pr, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(150, 152, 165), TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 12), Parent = b })
	local badge = new("TextLabel", { BackgroundColor3 = T.accent, Text = "ON", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = WHITE, Size = UDim2.fromOffset(26, 14), Position = UDim2.new(1, -32, 0, 6), Visible = false, Parent = b }); rd(badge, 7)
	onAccent(function(c) badge.BackgroundColor3 = c end)
	conn(b.Activated, function() onClick(item, isBundle) end)
	return { id = id, badge = badge, stroke = st, name = nm, price = price, named = item.Name ~= nil, isBundle = isBundle, btn = b }
end

----------------------------------------------------------------------
-- CATALOG
----------------------------------------------------------------------
do
	local P = AV.pages.Catalog
	local groups = {
		{ hdr = "ACCESSORIES", items = { { key = "Hat", label = "Hats" }, { key = "HairAccessory", label = "Hair" }, { key = "FaceAccessory", label = "Face" }, { key = "NeckAccessory", label = "Neck" }, { key = "ShoulderAccessory", label = "Shoulder" }, { key = "FrontAccessory", label = "Front" }, { key = "BackAccessory", label = "Back" }, { key = "WaistAccessory", label = "Waist" } } },
		{ hdr = "CLOTHING", items = { { key = "Shirt", label = "Shirts" }, { key = "Pants", label = "Pants" }, { key = "TShirt", label = "T-Shirts" }, { key = "JacketAccessory", label = "Jackets" }, { key = "SweaterAccessory", label = "Sweaters" }, { key = "ShortsAccessory", label = "Shorts" }, { key = "DressSkirtAccessory", label = "Dresses" }, { key = "LeftShoeAccessory", label = "Left shoe" }, { key = "RightShoeAccessory", label = "Right shoe" } } },
		{ hdr = "BODY", items = { { key = "Head", label = "Heads" }, { key = "Face", label = "Faces" }, { key = "Torso", label = "Torsos" }, { key = "LeftArm", label = "Left arms" }, { key = "RightArm", label = "Right arms" }, { key = "LeftLeg", label = "Left legs" }, { key = "RightLeg", label = "Right legs" } } },
		{ hdr = "BUNDLES", items = { { key = "BundleBody", label = "Body bundles" }, { key = "BundleAnim", label = "Anim bundles" } } },
		{ hdr = "FEATURED", items = { { key = "Popular", label = "Popular" } } },
	}
	local catLabel = {}
	for _, g in ipairs(groups) do for _, it in ipairs(g.items) do catLabel[it.key] = it.label end end
	AV.catKey, AV.sort = "Hat", "Relevance"
	local rail = buildRail(P, groups, function(key) AV.catKey = key; AV.doSearch(false) end)
	AV.rail = rail

	local main = new("Frame", { Position = UDim2.fromOffset(132, 0), Size = UDim2.new(1, -132, 1, 0), BackgroundTransparency = 1, Parent = P })
	local function inputBox(ph, pos, size)
		local tb = new("TextBox", { PlaceholderText = ph, Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, TextXAlignment = Enum.TextXAlignment.Left, Position = pos, Size = size, Parent = main }); rd(tb, 9)
		stroke(tb, WHITE, 0.92); new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = tb })
		return tb
	end
	local function topBtn(text, pos, w, cb, accent)
		local b = new("TextButton", { Text = text, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = accent and T.accent or WHITE, BackgroundTransparency = accent and 0.65 or 0.92, Position = pos, Size = UDim2.fromOffset(w, 30), AutoButtonColor = false, Parent = main }); rd(b, 9)
		if accent then onAccent(function(c) b.BackgroundColor3 = c end) end
		conn(b.Activated, function() pcall(cb) end)
		return b
	end
	AV.searchBox = inputBox("Search catalog…", UDim2.fromOffset(0, 0), UDim2.new(1, -176, 0, 30))
	topBtn("Search", UDim2.new(1, -170, 0, 0), 62, function() AV.doSearch(false) end, true)
	local sortBtn = topBtn("Relevance", UDim2.new(1, -102, 0, 0), 102, function() end)
	local sorts = { "Relevance", "MostFavorited", "Bestselling", "RecentlyCreated", "PriceLowToHigh", "PriceHighToLow" }
	conn(sortBtn.Activated, function()
		local i = table.find(sorts, AV.sort) or 0
		AV.sort = sorts[i % #sorts + 1]; sortBtn.Text = AV.sort; AV.doSearch(false)
	end)
	local idBox = inputBox("Wear by asset ID…", UDim2.fromOffset(0, 36), UDim2.new(1, -176, 0, 30))
	topBtn("Wear ID", UDim2.new(1, -170, 0, 36), 82, function()
		local id = tonumber(idBox.Text)
		if id then AV.wearAsset(id, "#" .. id, AV.catKey) else notify("Enter a numeric asset id") end
	end, true)
	topBtn("Wearing ›", UDim2.new(1, -82, 0, 36), 82, function() AV.selectTab("Wearing") end)
	AV.hdr = label(main, "Hats", 12, T.sub, Enum.Font.GothamBold); AV.hdr.Position = UDim2.fromOffset(2, 72); AV.hdr.Size = UDim2.new(1, 0, 0, 18)
	AV.results = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 1, -94), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE, Parent = main })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = AV.results })
	new("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = AV.results })
	AV.cards = {}

	local popular = {
		{ Id = 1365767, Name = "Valkyrie Helm", ItemType = "Asset" }, { Id = 21070012, Name = "Dominus Empyreus", ItemType = "Asset" }, { Id = 48545806, Name = "Dominus Frigidus", ItemType = "Asset" },
		{ Id = 1031429, Name = "Domino Crown", ItemType = "Asset" }, { Id = 1285307, Name = "Sparkle Time Fedora", ItemType = "Asset" },
		{ Id = 139607718, Name = "Korblox Deathspeaker (right leg)", ItemType = "Asset", cat = "RightLeg" }, { Id = 134082579, Name = "Headless Head", ItemType = "Asset", cat = "Head" },
	}
	function AV.paintResults()
		for _, c in ipairs(AV.cards) do
			if not c.isBundle then
				local on = AV.isWorn(c.id) ~= nil
				c.badge.Visible = on; c.stroke.Transparency = on and 0 or 0.85
			end
		end
	end
	local function onCard(item, isBundle)
		if isBundle then AV.wearBundle(item.Id, item.Name); return end
		if AV.isWorn(item.Id) then AV.takeOffId(item.Id) else AV.wearAsset(item.Id, item.Name, item.cat or AV.catKey) end
	end
	function AV.fill(items, append)
		if not append then
			for _, c in ipairs(AV.results:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
			AV.cards = {}
		else
			local more = AV.results:FindFirstChild("MoreBtn"); if more then more:Destroy() end
		end
		local fresh = {}
		for _, it in ipairs(items or {}) do
			local ok, card = pcall(makeCard, AV.results, it, #AV.cards + 1, onCard)
			if ok and card then AV.cards[#AV.cards + 1] = card; fresh[#fresh + 1] = card end
		end
		AV.hdr.Text = (catLabel[AV.catKey] or "Results") .. "  ·  " .. #AV.cards .. " items"
		if #AV.cards == 0 then AV.hdr.Text = (catLabel[AV.catKey] or "Results") .. "  ·  no results" end
		fetchNames(fresh, AV.catKey == "BundleBody" or AV.catKey == "BundleAnim")
		if AV.pages_ and not AV.pages_.IsFinished and AV.catKey ~= "Popular" and #AV.cards > 0 then
			local m = new("TextButton", { Name = "MoreBtn", Text = "Load more", TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = T.accent, BackgroundTransparency = 0.7, LayoutOrder = 999999, AutoButtonColor = false, Parent = AV.results }); rd(m, 12)
			onAccent(function(c) m.BackgroundColor3 = c end)
			conn(m.Activated, function() AV.doSearch(true) end)
		end
		AV.paintResults()
	end
	AV.searchToken = 0
	function AV.doSearch(append)
		AV.searchToken += 1
		local tok = AV.searchToken
		if AV.catKey == "Popular" then AV.pages_ = nil; AV.fill(popular, false); return end
		AV.hdr.Text = (catLabel[AV.catKey] or "") .. "  ·  loading…"
		if not append then for _, c in ipairs(AV.results:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end; AV.cards = {} end
		task.spawn(function()
			local ok, err = pcall(function()
				if append and AV.pages_ and not AV.pages_.IsFinished then
					AV.pages_:AdvanceToNextPageAsync()
				else
					local bundle = (AV.catKey == "BundleBody" and "body") or (AV.catKey == "BundleAnim" and "anim") or nil
					local pages, e = searchPages(AV.searchBox.Text, { AV.catKey }, bundle, AV.sort, false)
					if not pages then error(e or "search failed") end
					AV.pages_ = pages
				end
				if tok ~= AV.searchToken then return end
				AV.fill(AV.pages_:GetCurrentPage(), append and true or false)
			end)
			if not ok and tok == AV.searchToken then
				AV.hdr.Text = (catLabel[AV.catKey] or "") .. "  ·  search failed"
				notify("Catalog error: " .. tostring(err):sub(1, 46))
			end
		end)
	end
	conn(AV.searchBox.FocusLost, function(enter) if enter then AV.doSearch(false) end end)
	AV.search = function(keyword, key) AV.searchBox.Text = keyword or ""; AV.catKey = key or "BundleBody"; rail.select(AV.catKey, true); AV.selectTab("Catalog"); AV.doSearch(false) end
	rail.select("Hat", true)
	task.defer(function() AV.fill({}, false); AV.hdr.Text = "Hats  ·  tap Search to load" end)
end

-- bundle wearing (needs HTTP to read bundle contents)
function AV.wearBundle(id, name)
	task.spawn(function()
		local body = httpGet("https://catalog.roblox.com/v1/bundles/" .. id .. "/details")
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if not (body and ok and data and data.items) then notify("Reading bundles needs HTTP access (unavailable here)"); return end
		local n = 0
		for _, it in ipairs(data.items) do
			if it.type == "Asset" then
				local obj = loadAsset(it.id)
				if obj then n += AV.attach(obj, it.id) end
			end
		end
		notify(n > 0 and ("Applied bundle · " .. (name or id)) or "Bundle had nothing wearable")
		if AV.refreshWorn then AV.refreshWorn() end; AV.schedule()
	end)
end

----------------------------------------------------------------------
-- ANIMATIONS  (per-slot builder: Idle / Walk / Run / Jump / Fall / Climb / Swim)
----------------------------------------------------------------------
do
	local P = AV.pages.Animations
	local prev = S.building; S.building = nil
	local Packs = {
		Ninja = { idle = { 656117400, 656118341 }, walk = 656121766, run = 656118852, jump = 656117878, fall = 656115606, climb = 656114359, swim = 656119721 },
		Zombie = { idle = { 616158929, 616160636 }, walk = 616168032, run = 616163682, jump = 616161997, fall = 616157476, climb = 616156119, swim = 616165109 },
		Levitation = { idle = { 616006778, 616008087 }, walk = 616013216, run = 616010382, jump = 616008936, fall = 616005863, climb = 616003713, swim = 616011509 },
		Robot = { idle = { 616088211, 616089559 }, walk = 616095330, run = 616091570, jump = 616090535, fall = 616087089, climb = 616086039, swim = 616092998 },
		Stylish = { idle = { 616136790, 616138447 }, walk = 616146177, run = 616140816, jump = 616139451, fall = 616134815, climb = 616133594, swim = 616143378 },
		Superhero = { idle = { 616111295, 616113536 }, walk = 616122287, run = 616117076, jump = 616115533, fall = 616108001, climb = 616104706, swim = 616119360 },
		Werewolf = { idle = { 1083195517, 1083214717 }, walk = 1083178339, run = 1083216690, jump = 1083218792, fall = 1083189019, climb = 1083182000 },
		Mage = { idle = { 707742142, 707855907 }, walk = 707897309, run = 707861613, jump = 707853694, fall = 707829716, climb = 707826056, swim = 707876443 },
		Cartoony = { idle = { 742637544, 742638445 }, walk = 742640026, run = 742638842, jump = 742637942, fall = 742637151, climb = 742636889, swim = 742639220 },
		Toy = { idle = { 782841498, 782845736 }, walk = 782843345, run = 782842708, jump = 782847020, fall = 782846423, climb = 782843869, swim = 782844582 },
		Pirate = { idle = { 750781874, 750782770 }, walk = 750785693, run = 750783738, jump = 750782230, fall = 750780242, climb = 750779899, swim = 750784579 },
		Vampire = { idle = { 1083445855, 1083450166 }, walk = 1083473930, run = 1083462077, jump = 1083455352, fall = 1083443587, climb = 1083439238, swim = 1083222527 },
		Elder = { idle = { 845397899, 845400520 }, walk = 845403856, run = 845386501, jump = 845398858, fall = 845396048, climb = 845392038, swim = 845401742 },
		Astronaut = { idle = { 891621366, 891633237 }, walk = 891667138, run = 891636393, jump = 891627522, fall = 891617961, climb = 891609353, swim = 891663592 },
		Bubbly = { idle = { 910004836, 910009958 }, walk = 910034870, run = 910025107, jump = 910016857, fall = 910001910, climb = 909997997, swim = 910028158 },
		Knight = { idle = { 657595757, 657568135 }, walk = 657552124, run = 657564596, jump = 658409194, fall = 657600338, climb = 658360781, swim = 657560551 },
	}
	local packOrder = { "Ninja", "Zombie", "Levitation", "Robot", "Stylish", "Superhero", "Werewolf", "Mage", "Cartoony", "Toy", "Pirate", "Vampire", "Elder", "Astronaut", "Bubbly", "Knight" }
	local Slots = {
		Idle = { { "idle", "Animation1" }, { "idle", "Animation2" } }, Walk = { { "walk", "WalkAnim" } }, Run = { { "run", "RunAnim" } },
		Jump = { { "jump", "JumpAnim" } }, Fall = { { "fall", "FallAnim" } }, Climb = { { "climb", "ClimbAnim" } }, Swim = { { "swim", "Swim" } },
	}
	local slotNames = { "Idle", "Walk", "Run", "Jump", "Fall", "Climb", "Swim" }
	local assetNames = { Idle = "IdleAnimation", Walk = "WalkAnimation", Run = "RunAnimation", Jump = "JumpAnimation", Fall = "FallAnimation", Climb = "ClimbAnimation", Swim = "SwimAnimation" }
	AV.animOrig = {}
	AV.slot = "Idle"
	local function animate() local ch = LP.Character; return ch and ch:FindFirstChild("Animate"), ch and ch:FindFirstChildOfClass("Humanoid") end
	local function reload(an, hum)
		AV.reloadId = (AV.reloadId or 0) + 1
		local id = AV.reloadId
		task.delay(0.15, function()
			if id ~= AV.reloadId or not an.Parent then return end
			an.Disabled = true
			for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end
			task.wait(0.1); an.Disabled = false
		end)
	end
	local rail
	local function setSlot(slot, ids, labelText)
		local an, hum = animate()
		if not an then notify("This character has no Animate script"); return end
		AV.animOrig[slot] = AV.animOrig[slot] or {}
		for i, sl in ipairs(Slots[slot]) do
			local v = an:FindFirstChild(sl[1])
			if not v then v = Instance.new("StringValue"); v.Name = sl[1]; v.Parent = an end
			local a = v:FindFirstChild(sl[2])
			if not a then a = Instance.new("Animation"); a.Name = sl[2]; a.Parent = v end
			if AV.animOrig[slot][i] == nil then AV.animOrig[slot][i] = a.AnimationId end
			if ids == nil then a.AnimationId = AV.animOrig[slot][i]
			else a.AnimationId = "rbxassetid://" .. (type(ids) == "table" and (ids[i] or ids[1]) or ids) end
		end
		AV.buildIds[slot] = ids; AV.buildNames[slot] = ids and labelText or nil
		if rail then rail.setSub(slot, ids and labelText or "Default") end
		reload(an, hum)
		notify(slot .. " · " .. (ids and labelText or "Default"))
		if AV.rebuildAnimInfo then AV.rebuildAnimInfo() end
	end
	AV.setSlot = setSlot

	local groups = { { hdr = "ANIMATION BUILD", items = {} } }
	for _, s in ipairs(slotNames) do groups[1].items[#groups[1].items + 1] = { key = s, label = s, sub = "Default" } end
	rail = buildRail(P, groups, function(key) AV.slot = key; AV.rebuildAnimMain() end)
	local main = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(132, 0), Size = UDim2.new(1, -132, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE, Parent = P })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = main })
	new("UIPadding", { PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), Parent = main })

	local hdr = label(main, "Idle", 16, T.text, Enum.Font.GothamBold); hdr.Size = UDim2.new(1, 0, 0, 22); hdr.LayoutOrder = lo()
	local cur = label(main, "Currently: Default", 11, T.sub, Enum.Font.Gotham); cur.Size = UDim2.new(1, 0, 0, 14); cur.LayoutOrder = lo()
	local s1 = sec(main, "Presets (pick a pack for this slot)")
	local presetBox = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = s1 })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = presetBox })
	local s2 = sec(main, "Search catalog animations")
	local r = row(s2, "Keyword")
	local tb = new("TextBox", { PlaceholderText = "e.g. zombie, dance, sword…", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -80, .5, 0), Size = UDim2.fromOffset(170, 26), Parent = r }); rd(tb, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = tb })
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = s2 })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local note = info(s2, "Search results appear here. Tap one to use it for the selected slot.", 28); note.Parent.LayoutOrder = 0
	local function animSearch()
		if not AES then notify("Catalog service unavailable"); return end
		note.Text = "Searching…"
		task.spawn(function()
			local ok, err = pcall(function()
				local pages, e = searchPages(tb.Text, { assetNames[AV.slot] }, nil, "Relevance", false)
				if not pages then error(e) end
				for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
				local cards = {}
				for i, it in ipairs(pages:GetCurrentPage()) do
					local okc, card = pcall(makeCard, grid, it, i, function(item) setSlot(AV.slot, item.Id, item.Name or ("#" .. item.Id)) end)
					if okc and card then cards[#cards + 1] = card end
				end
				fetchNames(cards, false)
				note.Text = #cards .. " animations for " .. AV.slot
			end)
			if not ok then note.Text = "Search failed"; notify("Catalog error: " .. tostring(err):sub(1, 40)) end
		end)
	end
	miniBtn(r, "Search", -10, 64, animSearch, true)
	conn(tb.FocusLost, function(enter) if enter then animSearch() end end)
	local s3 = sec(main, "Custom animation ID")
	local r3 = row(s3, "Animation ID")
	local tb3 = new("TextBox", { PlaceholderText = "id", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, PlaceholderColor3 = T.sub, BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -80, .5, 0), Size = UDim2.fromOffset(170, 26), Parent = r3 }); rd(tb3, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = tb3 })
	miniBtn(r3, "Use", -10, 64, function() local id = tonumber(tb3.Text); if id then setSlot(AV.slot, id, "#" .. id) else notify("Enter a numeric animation id") end end, true)
	btn(s3, "Reset this slot", function() setSlot(AV.slot, nil) end, "Reset")
	btn(s3, "Reset whole build", function() for _, s in ipairs(slotNames) do if AV.buildIds[s] ~= nil then setSlot(s, nil) end end end, "Reset all")

	function AV.rebuildAnimInfo() cur.Text = "Currently: " .. (AV.buildNames[AV.slot] or "Default") end
	function AV.rebuildAnimMain()
		hdr.Text = AV.slot .. " animation"
		AV.rebuildAnimInfo()
		for _, c in ipairs(presetBox:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		local key = AV.slot:lower()
		local n = 0
		for _, name in ipairs(packOrder) do
			local v = Packs[name][key]
			if v then
				n += 1
				local b = new("TextButton", { Text = name, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), AutoButtonColor = false, LayoutOrder = n, Parent = presetBox }); rd(b, 14)
				new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = b })
				conn(b.Activated, function() setSlot(AV.slot, v, name) end)
			end
		end
	end
	-- emotes & dances
	local s4 = sec(main, "Emotes & dances")
	local track
	local function play(id, name)
		local ch, hum = myChar(); if not hum then return end
		if track then pcall(function() track:Stop(0.2) end) end
		local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://" .. id
		local animator = hum:FindFirstChildOfClass("Animator") or hum
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if ok and t then
			track = t; t.Looped = F.av_loop; t.Priority = Enum.AnimationPriority.Action; t:Play(0.2); t:AdjustSpeed(F.av_aspeed)
			notify("Playing · " .. name)
		else notify("Couldn't play that animation") end
	end
	tog(s4, "Loop emote", "av_loop", true, function(v) if track then track.Looped = v end end)
	sld(s4, "Emote speed", "av_aspeed", 0.2, 3, 1, 0.05, function(v) if track then pcall(function() track:AdjustSpeed(v) end) end end, "x")
	local eb = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = lo(), Parent = s4 })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), Parent = eb })
	for _, e in ipairs({ { "Dance 1", 507771019 }, { "Dance 2", 507776043 }, { "Dance 3", 507777268 }, { "Wave", 507770239 }, { "Point", 507770453 }, { "Cheer", 507770677 }, { "Laugh", 507770818 } }) do
		local b = new("TextButton", { Text = e[1], TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), AutoButtonColor = false, Parent = eb }); rd(b, 14)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = b })
		conn(b.Activated, function() play(e[2], e[1]) end)
	end
	btn(s4, "Stop emote", function() if track then pcall(function() track:Stop(0.2) end); track = nil end end, "Stop")
	AV.stopAnim = function() if track then pcall(function() track:Stop(0) end) end end
	rail.select("Idle", true)
	AV.rebuildAnimMain()
	S.building = prev
end

----------------------------------------------------------------------
-- WEARING (take-off manager)
----------------------------------------------------------------------
do
	local P = AV.pages.Wearing
	local prev = S.building; S.building = nil
	local s = sec(P, "Actions")
	btn(s, "Take off all accessories", function()
		local ch = LP.Character; if not ch then return end
		for _, c in ipairs(ch:GetChildren()) do if c:IsA("Accessory") then AV.removed[#AV.removed + 1] = { inst = c, parent = ch }; c.Parent = nil end end
		AV.descIds = {}
		AV.refreshWorn(); AV.schedule(); if AV.paintResults then AV.paintResults() end; notify("Accessories removed")
	end, "Remove")
	btn(s, "Take off shirt / pants / t-shirt", function()
		local ch = LP.Character; if not ch then return end
		for _, c in ipairs(ch:GetChildren()) do if c:IsA("Clothing") or c:IsA("ShirtGraphic") then AV.removed[#AV.removed + 1] = { inst = c, parent = ch }; c.Parent = nil end end
		AV.refreshWorn(); AV.schedule(); notify("Clothing removed")
	end, "Remove")
	btn(s, "Undo last take-off", function() AV.undo() end, "Undo")
	AV.wornBody = sec(P, "Currently wearing")
	S.building = prev
	function AV.refreshWorn()
		if not AV.wornBody then return end
		for _, c in ipairs(AV.wornBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		local ch = LP.Character; if not ch then return end
		local p2 = S.building; S.building = nil
		local count = 0
		local function addRow(inst, kind, thumbId)
			count += 1
			local r, l = row(AV.wornBody, inst.Name, 52)
			local img = new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(24, 24, 30), Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(38, 38), ScaleType = Enum.ScaleType.Fit, Parent = r }); rd(img, 8)
			if thumbId then img.Image = ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(thumbId) end
			l.Position = UDim2.fromOffset(54, 6); l.Size = UDim2.new(0.5, 0, 0, 20); l.TextTruncate = Enum.TextTruncate.AtEnd
			local k = label(r, kind, 10, T.sub, Enum.Font.Gotham); k.Position = UDim2.fromOffset(54, 26); k.Size = UDim2.new(0.5, 0, 0, 14)
			miniBtn(r, "Take off", -10, 70, function() AV.takeOff(inst) end, true)
		end
		for _, c in ipairs(ch:GetChildren()) do
			if c:IsA("Accessory") then
				local id = AV.worn[c] or AV.nameToId[c.Name]
				local at = ""; pcall(function() at = tostring(c.AccessoryType):gsub("Enum.AccessoryType.", "") end)
				addRow(c, "Accessory  ·  " .. at, id)
			elseif c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
				local tpl = c:IsA("Shirt") and c.ShirtTemplate or (c:IsA("Pants") and c.PantsTemplate or c.Graphic)
				addRow(c, c.ClassName, tonumber(tostring(tpl):match("(%d+)$")))
			end
		end
		local head = ch:FindFirstChild("Head"); local face = head and head:FindFirstChild("face")
		if face and face:IsA("Decal") then addRow(face, "Face", tonumber(tostring(face.Texture):match("(%d+)$"))) end
		if count == 0 then row(AV.wornBody, "Nothing worn right now", 38) end
		AV.info.Text = count .. " items worn  ·  " .. #AV.removed .. " in undo stack"
		S.building = p2
	end
end

----------------------------------------------------------------------
-- BUNDLES (body parts: head / torso / left+right arm / left+right leg)
----------------------------------------------------------------------
do
	local P = AV.pages.Bundles
	local prev = S.building; S.building = nil
	local LIMBS = {
		{ "Head", "Head", { "Head" }, "Head" }, { "Torso", "Torso", { "UpperTorso", "LowerTorso", "Torso" }, "Torso" },
		{ "LeftArm", "Left Arm", { "LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm" }, "LeftArm" }, { "RightArm", "Right Arm", { "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" }, "RightArm" },
		{ "LeftLeg", "Left Leg", { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Left Leg" }, "LeftLeg" }, { "RightLeg", "Right Leg", { "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }, "RightLeg" },
	}
	local limbMap = {}
	for _, l in ipairs(LIMBS) do limbMap[l[1]] = l end
	local function limbParts(kind)
		local ch = LP.Character; if not ch then return {} end
		local out = {}
		for _, n in ipairs(limbMap[kind][3]) do local p = ch:FindFirstChild(n); if p and p:IsA("BasePart") then out[#out + 1] = p end end
		return out
	end
	local function stash(p)
		if p:GetAttribute("AmbT") == nil then p:SetAttribute("AmbT", p.Transparency); p:SetAttribute("AmbMat", p.Material.Name); p:SetAttribute("AmbCol", p.Color) end
	end
	local function setHidden(kind, v) for _, p in ipairs(limbParts(kind)) do stash(p); p.Transparency = v and 1 or p:GetAttribute("AmbT") end end
	local function resetLimb(kind)
		for _, p in ipairs(limbParts(kind)) do
			if p:GetAttribute("AmbT") ~= nil then p.Transparency = p:GetAttribute("AmbT"); p.Material = Enum.Material[p:GetAttribute("AmbMat")]; p.Color = p:GetAttribute("AmbCol") end
			if p:IsA("MeshPart") and p:GetAttribute("AmbMesh") then p.MeshId = p:GetAttribute("AmbMesh"); p.TextureID = p:GetAttribute("AmbTex") end
		end
		AV.schedule()
	end
	local s = sec(P, "Body parts")
	info(s, "Hide a part, browse real catalog parts for it, or reset it. Parts applied from the catalog only change your own view.", 34)
	for _, l in ipairs(LIMBS) do
		local r = row(s, l[2])
		local hidden = false
		local hb
		hb = miniBtn(r, "Hide", -10, 50, function() hidden = not hidden; setHidden(l[1], hidden); hb.Text = hidden and "Show" or "Hide"; AV.schedule() end)
		miniBtn(r, "Reset", -66, 50, function() hidden = false; hb.Text = "Hide"; resetLimb(l[1]) end)
		miniBtn(r, "Browse", -122, 62, function()
			local key = l[4]
			AV.rail.select(key, true); AV.catKey = key; AV.selectTab("Catalog"); AV.doSearch(false)
		end, true)
	end
	local s2 = sec(P, "Instant bundles")
	tog(s2, "Headless", "av_headless", false, function(v)
		local ch = LP.Character; if not ch then return end
		setHidden("Head", v)
		local head = ch:FindFirstChild("Head"); local face = head and head:FindFirstChild("face")
		if face and face:IsA("Decal") then face:SetAttribute("AmbT", face:GetAttribute("AmbT") or face.Transparency); face.Transparency = v and 1 or face:GetAttribute("AmbT") end
		AV.schedule()
	end)
	local function korblox(side, v)
		local ch, hum = myChar(); if not ch then return end
		if hum.RigType ~= Enum.HumanoidRigType.R15 then notify("Korblox needs an R15 character"); return false end
		local pre = side
		local set = { [pre .. "UpperLeg"] = "902942096", [pre .. "LowerLeg"] = "902942093", [pre .. "Foot"] = "902942089" }
		for n, mesh in pairs(set) do
			local p = ch:FindFirstChild(n)
			if p and p:IsA("MeshPart") then
				if not p:GetAttribute("AmbMesh") then p:SetAttribute("AmbMesh", p.MeshId); p:SetAttribute("AmbTex", p.TextureID) end
				if v then p.MeshId = "rbxassetid://" .. mesh; if n:find("Foot") then p.TextureID = "rbxassetid://902843398" end
				else p.MeshId = p:GetAttribute("AmbMesh"); p.TextureID = p:GetAttribute("AmbTex") end
			end
		end
		AV.schedule()
	end
	tog(s2, "Korblox Deathspeaker (right leg)", "av_korblox_r", false, function(v) if korblox("Right", v) == false then task.defer(function() UI.av_korblox_r(false) end) end end)
	tog(s2, "Korblox style (left leg, mirrored look)", "av_korblox_l", false, function(v) if korblox("Left", v) == false then task.defer(function() UI.av_korblox_l(false) end) end end)
	tog(s2, "Hide face", "av_noface", false, function(v)
		local ch = LP.Character; local head = ch and ch:FindFirstChild("Head"); local face = head and head:FindFirstChild("face")
		if face and face:IsA("Decal") then face:SetAttribute("AmbT", face:GetAttribute("AmbT") or face.Transparency); face.Transparency = v and 1 or face:GetAttribute("AmbT") end
		AV.schedule()
	end)
	tog(s2, "Hide all accessories", "av_hideacc", false, function(v)
		local ch = LP.Character; if not ch then return end
		for _, a in ipairs(ch:GetChildren()) do
			if a:IsA("Accessory") then
				local h = a:FindFirstChild("Handle")
				if h then h:SetAttribute("AmbT", h:GetAttribute("AmbT") or h.Transparency); h.Transparency = v and 1 or h:GetAttribute("AmbT") end
			end
		end
		AV.schedule()
	end)
	local s3 = sec(P, "Limb style")
	chips(s3, "Limb", "av_limb", { "All", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }, "All")
	chips(s3, "Material", "av_mat", { "SmoothPlastic", "Plastic", "Neon", "Glass", "ForceField", "Metal", "Foil" }, "SmoothPlastic", function(v) AV.styleLimbs() end)
	sld(s3, "Transparency", "av_ltrans", 0, 1, 0, 0.05, function() AV.styleLimbs() end)
	tog(s3, "Use custom color", "av_lcol", false, function() AV.styleLimbs() end)
	sld(s3, "Color hue", "av_lhue", 0, 360, 200, 1, function() if F.av_lcol then AV.styleLimbs() end end)
	sld(s3, "Color brightness", "av_lval", 0, 100, 90, 1, function() if F.av_lcol then AV.styleLimbs() end end, "%")
	function AV.styleLimbs()
		local targets = {}
		if F.av_limb == "All" then for _, l in ipairs(LIMBS) do targets[#targets + 1] = l[1] end else targets[1] = F.av_limb end
		for _, k in ipairs(targets) do
			for _, p in ipairs(limbParts(k)) do
				stash(p)
				p.Material = Enum.Material[F.av_mat]
				p.Transparency = F.av_ltrans
				if F.av_lcol then p.Color = Color3.fromHSV(F.av_lhue / 360, 0.7, F.av_lval / 100) else p.Color = p:GetAttribute("AmbCol") end
			end
		end
		AV.schedule()
	end
	btn(s3, "Reset all limbs", function() for _, l in ipairs(LIMBS) do resetLimb(l[1]) end; UI.av_headless(false); UI.av_korblox_r(false); UI.av_korblox_l(false); notify("Body reset") end, "Reset")
	local s4 = sec(P, "Find real bundles in the catalog")
	info(s4, "Opens the catalog with bundle results. Tapping a bundle applies its parts (needs HTTP access to read bundle contents).", 36)
	chips(s4, "Quick search", "av_bundle_q", { "Korblox", "Headless", "Skeleton", "Zombie", "Robot", "Ninja", "Dragon", "Cat", "Anime", "Knight" }, "Korblox", function(v) AV.search(v, "BundleBody") end)
	S.building = prev
end

----------------------------------------------------------------------
-- BODY (skin, scale, R6 look)
----------------------------------------------------------------------
do
	local P = AV.pages.Body
	local prev = S.building; S.building = nil
	local function bodyColors()
		local ch = LP.Character; if not ch then return end
		local bc = ch:FindFirstChildOfClass("BodyColors")
		if not bc then bc = Instance.new("BodyColors"); bc.Parent = ch end
		return bc
	end
	local props = {
		All = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" },
		Head = { "HeadColor3" }, Torso = { "TorsoColor3" }, Arms = { "LeftArmColor3", "RightArmColor3" }, Legs = { "LeftLegColor3", "RightLegColor3" },
	}
	local function paintSkin(col)
		local bc = bodyColors(); if not bc then return end
		for _, p in ipairs(props[F.av_part or "All"]) do pcall(function() bc[p] = col end) end
		AV.schedule()
	end
	local tones = {
		Pale = Color3.fromRGB(255, 224, 205), Light = Color3.fromRGB(242, 195, 165), Tan = Color3.fromRGB(215, 160, 120), Brown = Color3.fromRGB(150, 100, 70),
		Dark = Color3.fromRGB(85, 55, 40), Zombie = Color3.fromRGB(120, 170, 100), Blue = Color3.fromRGB(110, 150, 230), Pink = Color3.fromRGB(255, 150, 200),
		Gold = Color3.fromRGB(235, 190, 70), Silver = Color3.fromRGB(190, 195, 205), Black = Color3.fromRGB(25, 25, 28), White = Color3.fromRGB(245, 245, 250),
	}
	local s = sec(P, "Skin & body color")
	chips(s, "Apply to", "av_part", { "All", "Head", "Torso", "Arms", "Legs" }, "All")
	chips(s, "Tone", "av_tone", { "Pale", "Light", "Tan", "Brown", "Dark", "Zombie", "Blue", "Pink", "Gold", "Silver", "Black", "White" }, "Light", function(v) paintSkin(tones[v]) end)
	local function custom() paintSkin(Color3.fromHSV(F.av_hue / 360, F.av_sat / 100, F.av_val / 100)) end
	sld(s, "Custom hue", "av_hue", 0, 360, 30, 1, custom)
	sld(s, "Saturation", "av_sat", 0, 100, 50, 1, custom, "%")
	sld(s, "Brightness", "av_val", 0, 100, 90, 1, custom, "%")
	local function scaleVal(name, v)
		local ch, hum = myChar(); local nv = hum and hum:FindFirstChild(name)
		if nv and nv:IsA("NumberValue") then nv.Value = v; AV.schedule() else notify("Scaling needs an R15 character") end
	end
	local s2 = sec(P, "Scale (R15)")
	sld(s2, "Height", "av_sh", 0.7, 1.3, 1, 0.01, function(v) scaleVal("BodyHeightScale", v) end)
	sld(s2, "Width", "av_sw", 0.5, 1.5, 1, 0.01, function(v) scaleVal("BodyWidthScale", v) end)
	sld(s2, "Depth", "av_sd", 0.5, 1.5, 1, 0.01, function(v) scaleVal("BodyDepthScale", v) end)
	sld(s2, "Head size", "av_shd", 0.5, 1.5, 1, 0.01, function(v) scaleVal("HeadScale", v) end)
	sld(s2, "Body type", "av_sbt", 0, 1, 0, 0.01, function(v) scaleVal("BodyTypeScale", v) end)
	sld(s2, "Proportions", "av_sbp", 0, 1, 0, 0.01, function(v) scaleVal("BodyProportionScale", v) end)
	local s3 = sec(P, "R6 look")
	info(s3, "True R6 needs the game to spawn you as R6. This gives an R15 body the classic blocky R6 proportions, locally.", 36)
	tog(s3, "Classic R6 proportions", "av_r6look", false, function(v)
		local ch, hum = myChar(); if not hum then return end
		local all = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale", "BodyTypeScale", "BodyProportionScale" }
		if v then
			AV.scaleOrig = {}
			for _, n in ipairs(all) do local nv = hum:FindFirstChild(n); if nv then AV.scaleOrig[n] = nv.Value end end
			for _, n in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do local nv = hum:FindFirstChild(n); if nv then nv.Value = 1 end end
			for _, n in ipairs({ "BodyTypeScale", "BodyProportionScale" }) do local nv = hum:FindFirstChild(n); if nv then nv.Value = 0 end end
			if not hum:FindFirstChild("BodyTypeScale") then notify("R6 character: already classic") end
		else
			for n, val in pairs(AV.scaleOrig or {}) do local nv = hum:FindFirstChild(n); if nv then nv.Value = val end end
		end
		AV.schedule()
	end)
	btn(s3, "Preview as real R6 rig", function() AV.rig = "R6"; AV.paintRig(); AV.buildPreview() end, "Preview")
	S.building = prev
end

----------------------------------------------------------------------
-- OUTFITS
----------------------------------------------------------------------
do
	local P = AV.pages.Outfits
	local prev = S.building; S.building = nil
	genv.AmbienceOutfits = genv.AmbienceOutfits or {}
	local function snapshot()
		local data = { ids = {}, colors = {}, anim = {}, animNames = {} }
		local seen = {}
		for inst, id in pairs(AV.worn) do if inst.Parent and not seen[id] then seen[id] = true; data.ids[#data.ids + 1] = id end end
		for slot, v in pairs(AV.buildIds) do data.anim[slot] = v; data.animNames[slot] = AV.buildNames[slot] end
		local ch = LP.Character; local bc = ch and ch:FindFirstChildOfClass("BodyColors")
		if bc then for _, p in ipairs({ "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }) do local c = bc[p]; data.colors[p] = { c.R, c.G, c.B } end end
		return data
	end
	local function restore(data)
		local ch = LP.Character; if not ch then return end
		for _, c in ipairs(ch:GetChildren()) do if c:IsA("Accessory") then c.Parent = nil end end
		AV.worn = {}
		for _, id in ipairs(data.ids or {}) do AV.wearAsset(id) end
		local bc = ch:FindFirstChildOfClass("BodyColors")
		if bc then for p, c in pairs(data.colors or {}) do pcall(function() bc[p] = Color3.new(c[1], c[2], c[3]) end) end end
		for slot, v in pairs(data.anim or {}) do pcall(AV.setSlot, slot, v, (data.animNames or {})[slot] or "saved") end
		AV.schedule()
	end
	local s = sec(P, "Outfit slots")
	for i = 1, 5 do
		local r = row(s, "Outfit " .. i)
		miniBtn(r, "Save", -10, 56, function()
			local d = snapshot(); local json = HttpService:JSONEncode(d)
			genv.AmbienceOutfits[i] = json
			pcall(function() if makefolder and not isfolder("Ambience") then makefolder("Ambience") end; if writefile then writefile("Ambience/outfit_" .. i .. ".json", json) end end)
			notify("Saved outfit " .. i .. " · " .. #d.ids .. " items")
		end)
		miniBtn(r, "Wear", -72, 56, function()
			local json = genv.AmbienceOutfits[i]
			pcall(function() if isfile and isfile("Ambience/outfit_" .. i .. ".json") then json = readfile("Ambience/outfit_" .. i .. ".json") end end)
			if not json then notify("Outfit " .. i .. " is empty"); return end
			local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
			if ok then restore(d); notify("Wearing outfit " .. i) end
		end, true)
	end
	info(s, "Outfits remember items worn through the studio, body colors and your animation build.", 34)
	S.building = prev
end

G.avCleanup = function() if AV.stopAnim then pcall(AV.stopAnim) end end
AV.paintRig()
AV.selectTab("Catalog")
end)()

----------------------------------------------------------------------
-- FREECAM
----------------------------------------------------------------------
G.fcOn, G.fcCF = false, nil
genv.__AmbienceFreecam = function(v)
	if v == G.fcOn then return end
	G.fcOn = v
	if v then
		G.fcCF = Cam.CFrame
		Cam.CameraType = Enum.CameraType.Scriptable
	else
		Cam.CameraType = Enum.CameraType.Custom
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then Cam.CameraSubject = hum end
	end
end
local function freecamStep(dt)
	if not G.fcOn or G.isOpen then return end
	local cf = Cam.CFrame
	local fwd = (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
	local side = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
	local up = (UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
	local v = Vector3.new(side, 0, -fwd)
	local move = cf.Position
	if v.Magnitude > 0 then move += (cf:VectorToWorldSpace(v.Unit)) * F.freecam_speed * dt end
	move += Vector3.new(0, up * F.freecam_speed * dt, 0)
	Cam.CFrame = CFrame.new(move) * (cf - cf.Position)
end

----------------------------------------------------------------------
-- MOVEMENT / COMBAT EXTRAS / RADAR / CHIP
----------------------------------------------------------------------
local flyBV, flyBG
local hbOrig, lastTrig = {}, 0
genv.__AmbienceClean = function()
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
end

local function moveStep(dt)
	local ch = LP.Character; if not ch then return end
	local hum, hrp = ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then return end
	-- keep movement direction decoupled from a camera the aimbot is steering
	if F.aim_decouple and F.aim_on and G.aimActive and G.locked and not F.shiftlock and not F.fly_on then
		local fwd = (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
		local side = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		local v = Vector3.new(side, 0, -fwd)
		if v.Magnitude > 0 then
			hum:Move(CFrame.Angles(0, G.moveYaw or 0, 0):VectorToWorldSpace(v.Unit), false)
		else
			hum:Move(Vector3.zero, false)
		end
	end
	local o = Orig.hum[hum]
	if not o then o = { ws = hum.WalkSpeed, jp = hum.JumpPower, ujp = hum.UseJumpPower, ar = hum.AutoRotate }; Orig.hum[hum] = o end
	local want = F.speed_on and F.speed or nil
	if F.sprint_on and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then want = (want or o.ws) * F.sprint_mult end
	if want then hum.WalkSpeed = want; o.modWS = true elseif o.modWS then hum.WalkSpeed = o.ws; o.modWS = false end
	if F.jump_on then hum.UseJumpPower = true; hum.JumpPower = F.jump; o.modJP = true elseif o.modJP then hum.UseJumpPower = o.ujp; hum.JumpPower = o.jp; o.modJP = false end
	if F.bhop and UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
	-- fly
	if F.fly_on then
		if not flyBV or flyBV.Parent ~= hrp then
			genv.__AmbienceClean()
			flyBV = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero, Parent = hrp })
			flyBG = new("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 1e4, Parent = hrp })
		end
		local md, look = hum.MoveDirection, Cam.CFrame.LookVector
		local sp, vs = F.fly_speed, F.fly_vspeed
		local vel = md * sp
		if F.fly_mode ~= "Classic" then
			local flat = Vector3.new(look.X, 0, look.Z)
			if md.Magnitude > 0 and flat.Magnitude > 0 then vel += Vector3.new(0, look.Y, 0) * sp * math.clamp(md:Dot(flat.Unit), 0, 1) end
		end
		if UIS:IsKeyDown(Enum.KeyCode.Space) or (UIS.TouchEnabled and hum.Jump) then vel += Vector3.new(0, vs, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then vel -= Vector3.new(0, vs, 0) end
		if F.fly_mode == "Smooth" then vel = flyBV.Velocity:Lerp(vel, math.clamp(dt * 7, 0, 1)) end
		flyBV.Velocity = vel; flyBG.CFrame = Cam.CFrame
	elseif flyBV then genv.__AmbienceClean() end
	-- hitbox
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local c2, h2, r2 = validChar(plr)
			if r2 then
				if F.hb_on and not (F.aim_team and sameTeam(plr)) and not Friends[plr.UserId] then
					if not hbOrig[r2] then hbOrig[r2] = { r2.Size, r2.Transparency, r2.CanCollide } end
					r2.Size = Vector3.new(F.hb_size, F.hb_size, F.hb_size); r2.Transparency = F.hb_trans; r2.CanCollide = false
				elseif hbOrig[r2] then
					r2.Size, r2.Transparency, r2.CanCollide = hbOrig[r2][1], hbOrig[r2][2], hbOrig[r2][3]; hbOrig[r2] = nil
				end
			end
		end
	end
	-- triggerbot
	if F.trig_on and os.clock() - lastTrig > F.trig_delay then
		local tgt = LP:GetMouse().Target
		local m = tgt and tgt:FindFirstAncestorOfClass("Model")
		local plr = m and Players:GetPlayerFromCharacter(m)
		if plr and plr ~= LP and not (F.aim_team and sameTeam(plr)) and not Friends[plr.UserId] then
			lastTrig = os.clock(); pcall(function() mouse1click() end)
		end
	end
end

local function worldStep(dt)
	if F.time_cycle then Lighting.ClockTime = (Lighting.ClockTime + dt * F.time_speed) % 24
	elseif F.freeze_time then Lighting.ClockTime = F.tod end
	local _, hum, hrp = myParts()
	if hum and hrp then
		G.safeT = (G.safeT or 0) + dt
		if hum.FloorMaterial ~= Enum.Material.Air and G.safeT > 0.5 then G.safeT = 0; G.lastSafe = hrp.CFrame end
		if F.antivoid and hrp.Position.Y < F.void_y then hrp.AssemblyLinearVelocity = Vector3.zero; hrp.CFrame = G.lastSafe or CFrame.new(0, 120, 0) end
	end
end

local function radarStep()
	G.Radar.Visible = F.radar
	if not F.radar then return end
	local _, _, hrp = validChar(LP)
	if not hrp then return end
	local yaw = math.atan2(-Cam.CFrame.LookVector.X, -Cam.CFrame.LookVector.Z)
	local i, range = 0, F.radar_range
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local _, _, r2 = validChar(plr)
			if r2 then
				i += 1
				local d = G.RadarDots[i]
				if not d then d = ovf({ AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = OVC, Parent = G.Radar }); rd(d, 3); G.RadarDots[i] = d end
				local rel = r2.Position - hrp.Position
				local x = rel.X * math.cos(yaw) - rel.Z * math.sin(yaw)
				local z = rel.X * math.sin(yaw) + rel.Z * math.cos(yaw)
				d.Position = UDim2.new(0.5, math.clamp(x / range, -1, 1) * 54, 0.5, math.clamp(z / range, -1, 1) * 54); d.Visible = true
				d.BackgroundColor3 = playerCol(plr)
			end
		end
	end
	for j = i + 1, #G.RadarDots do G.RadarDots[j].Visible = false end
end

----------------------------------------------------------------------
-- TABS (grouped sidebar) + page switching + search
----------------------------------------------------------------------
local TabDefs = {
	{ "Home", "home" },
	{ "#", "COMBAT" }, { "Aimbot", "aim" }, { "Combat", "combat" }, { "Teams", "teams" },
	{ "#", "VISUALS" }, { "ESP", "esp" }, { "Chams", "chams" }, { "Tracers", "tracers" }, { "HUD", "hud" },
	{ "#", "WORLD" }, { "World", "world" }, { "Skybox", "sky" }, { "Lighting", "light" },
	{ "#", "PLAYER" }, { "Movement", "move" }, { "Fly", "fly" }, { "Players", "players" }, { "Waypoints", "pin" }, { "Misc", "misc" },
	{ "#", "MENU" }, { "Colors", "palette" }, { "Effects", "fx" }, { "Fonts", "font" }, { "Configs", "config" }, { "Remote Spy", "spy" }, { "Game", "game" }, { "Settings", "settings" },
}
local Items = {}
local selectTab
local function paintTabs()
	local p = Pal[S.mode]
	for n, t in pairs(S.tabs) do
		local on = n == S.current
		t.lbl.TextColor3 = on and p.text or p.sub
		t.setCol(on and T.accent or p.sub)
		t.arrow.TextTransparency = on and 0 or 1
	end
	for _, it in ipairs(Items) do if it.kind == "hdr" then it.obj.TextColor3 = p.sub end end
end
local function relayout()
	local q = G.SSearch.Text:lower()
	local y = 0
	for _, it in ipairs(Items) do
		if it.kind == "hdr" then
			it.obj.Visible = (q == "")
			if q == "" then it.obj.Position = UDim2.fromOffset(8, y + 6); y += 26 end
		else
			local vis = q == "" or it.name:lower():find(q, 1, true) ~= nil
			it.obj.Visible = vis
			if vis then it.obj.Position = UDim2.fromOffset(0, y); S.tabs[it.name].y = y; y += 38 end
		end
	end
	G.TabList.CanvasSize = UDim2.fromOffset(0, y + 6)
	local t = S.current and S.tabs[S.current]
	if t and t.y then G.Pill.Position = UDim2.fromOffset(0, t.y) end
end
local function buildTabs()
	for _, d in ipairs(TabDefs) do
		if d[1] == "#" then
			local l = label(G.TabList, d[2], 9, T.sub, Enum.Font.GothamBold); l.Size = UDim2.new(1, -10, 0, 16)
			Items[#Items + 1] = { kind = "hdr", obj = l }
		else
			local name = d[1]
			local b = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), AutoButtonColor = false, ZIndex = 2, Parent = G.TabList })
			local ico, setCol = makeIcon(b, d[2], 18); ico.Position = UDim2.fromOffset(11, 8); ico.ZIndex = 3
			local lbl = label(b, name, 13, T.sub, Enum.Font.GothamMedium); lbl.Position = UDim2.fromOffset(40, 0); lbl.Size = UDim2.new(1, -66, 1, 0); lbl.ZIndex = 3
			local arrow = label(b, "›", 18, T.text, Enum.Font.GothamBold, Enum.TextXAlignment.Right); arrow.Size = UDim2.new(1, -10, 1, 0); arrow.TextTransparency = 1; arrow.ZIndex = 3
			S.tabs[name] = { lbl = lbl, setCol = setCol, arrow = arrow, btn = b }
			Items[#Items + 1] = { kind = "tab", obj = b, name = name }
			conn(b.Activated, function() selectTab(name) end)
			conn(b.MouseEnter, function() if S.current ~= name then tw(lbl, 0.15, { TextColor3 = Pal[S.mode].text }) end end)
			conn(b.MouseLeave, function() if S.current ~= name then tw(lbl, 0.15, { TextColor3 = Pal[S.mode].sub }) end end)
		end
	end
	relayout()
end
selectTab = function(name)
	local pg = S.pages[name]; if not pg then return end
	local first = S.current == nil
	S.current = name
	G.Title.Text = name; G.Crumb.Text = S.crumb[name] or ""
	PV.refresh(name)
	for n, sf in pairs(S.pages) do sf.Visible = (n == name) end
	pg.CanvasPosition = Vector2.new(0, 0)
	if first then for _, sf in pairs(S.pages) do sf.Size = pageW() end
	else
		pg.Size = pageW()
		pg.Position = UDim2.fromOffset(12, 72); tw(pg, 0.4, { Position = UDim2.fromOffset(12, 56) })
	end
	G.FSearch.Text = ""
	for _, sf in pairs(S.pages) do if sf ~= pg then sf.Size = pageW() end end
	paintTabs()
	local t = S.tabs[name]
	if t and t.y then
		tw(G.Pill, first and 0 or 0.35, { Position = UDim2.fromOffset(0, t.y) })
		local vis = G.TabList.AbsoluteSize.Y / G.UIs.Scale
		local cp = G.TabList.CanvasPosition.Y
		if t.y < cp then G.TabList.CanvasPosition = Vector2.new(0, t.y - 10)
		elseif t.y + 40 > cp + vis then G.TabList.CanvasPosition = Vector2.new(0, t.y + 40 - vis) end
	end
end
S.go = selectTab
watch("cmode", paintTabs)
onAccent(function() if S.current then paintTabs() end end)
conn(G.SSearch:GetPropertyChangedSignal("Text"), relayout)
conn(G.FSearch:GetPropertyChangedSignal("Text"), function()
	local q = G.FSearch.Text:lower()
	for _, r in ipairs(S.rows[S.current] or {}) do r[1].Visible = (q == "" or r[2]:find(q, 1, true) ~= nil) end
end)

----------------------------------------------------------------------
-- MAIN LOOPS + INPUT
----------------------------------------------------------------------
local fpsAcc, fpsN, fpsShown, rbT = 0, 0, 60, 0
local function eyeLook(E)
	if not UIS.MouseEnabled then return nil end
	local m = UIS:GetMouseLocation()
	local c = E.root.AbsolutePosition + E.root.AbsoluteSize / 2
	return (m.X - c.X) / 260, (m.Y - c.Y) / 260
end
conn(RS.RenderStepped, function(dt)
	local t = os.clock()
	pcall(function() if fxUpdate and G.Holder.Visible then fxUpdate(t * S.fxSpeed, dt * S.fxSpeed) end end)
	pcall(PV.step, t, dt)
	pcall(espStep); pcall(radarStep); pcall(wpStep); pcall(alStep, t); pcall(saStep); pcall(shiftStep, dt)
	pcall(function()
		if not (F.aim_decouple and F.aim_on and G.aimActive and G.locked) then
			local lv = Cam.CFrame.LookVector
			G.moveYaw = math.atan2(-lv.X, -lv.Z)
		end
	end)
	pcall(function()
		if S.rainbow and t - rbT > 0.04 then rbT = t; setAccent(Color3.fromHSV((t * (F.rb_speed or 6) * 0.02) % 1, 0.55, 1)) end
		for _, s in ipairs(S.swatches) do if F[s[2] .. "_rb"] then s[1].BackgroundColor3 = getCol(s[2]) end end
		for _, E in ipairs(Eyes) do
			if E.root.Parent and E.root.Visible and (E.root:IsDescendantOf(G.Gui) or E.root:IsDescendantOf(G.OV)) then
				local lx, ly = eyeLook(E); E.update(t, dt, lx, ly)
			end
		end
		fpsAcc += dt; fpsN += 1
		if fpsAcc >= 0.5 then fpsShown = math.floor(fpsN / fpsAcc + 0.5); fpsAcc, fpsN = 0, 0 end
		local parts = {}
		if F.wm then parts[#parts + 1] = "ambience" end
		if F.fps then
			parts[#parts + 1] = fpsShown .. " fps"
			local ok, ping = pcall(function() return math.floor(svc("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			if ok then parts[#parts + 1] = ping .. " ms" end
		end
		G.Chip.Visible = #parts > 0
		G.ChipL.Text = table.concat(parts, "  ·  ")
		G.Chip.Size = UDim2.fromOffset(math.max(84, #G.ChipL.Text * 6.6 + 42), 28)
		G.Pad.Visible = F.touchpad and UIS.TouchEnabled
		if G.fpsL then G.fpsL.Text = fpsShown .. " fps" end
		if G.srvPlayers and t - (G.srvT or 0) > 0.5 then
			G.srvT = t
			G.srvPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
			local ok, ping = pcall(function() return math.floor(svc("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			G.srvPing.Text = ok and (ping .. " ms") or "n/a"
			local up = math.floor(t - (G.t0 or t)); G.t0 = G.t0 or t
			G.srvUp.Text = string.format("%d:%02d", math.floor(up / 60), up % 60)
		end
	end)
end)
pcall(function() RS:BindToRenderStep("AmbienceAim", Enum.RenderPriority.Camera.Value + 1, function() pcall(aimStep) end) end)
conn(RS.Heartbeat, function(dt) pcall(moveStep, dt); pcall(worldStep, dt); pcall(freecamStep, dt) end)
conn(RS.Stepped, function()
	if (F.noclip or (F.fly_on and F.fly_noclip)) and LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
	end
end)
conn(LP.Idled, function() if F.antiafk then pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end) end end)
conn(UIS.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then G.firing = false end
end)
conn(UIS.InputChanged, function(i)
	if i.UserInputType == Enum.UserInputType.MouseMovement and F.aim_decouple and F.aim_on and G.aimActive and G.locked then
		G.moveYaw = (G.moveYaw or 0) - i.Delta.X * 0.0035
	end
end)
conn(UIS.JumpRequest, function()
	if F.inf_jump then local _, h = myParts(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end end
end)

conn(UIS.InputBegan, function(i, gp)
	if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and not G.isOpen then
		G.firing = true; G.saRoll = math.random(1, 100) <= (F.sa_hit or 100); G.saRollT = os.clock()
	end
	if listening and i.UserInputType == Enum.UserInputType.Keyboard then
		local f = listening; listening = nil
		f(i.KeyCode == Enum.KeyCode.Escape and "None" or i.KeyCode.Name); return
	end
	if UIS:GetFocusedTextBox() then return end
	if i.UserInputType == Enum.UserInputType.Keyboard then
		local k = i.KeyCode.Name
		if k == F.menukey then setOpen(not G.isOpen)
		elseif k == F.freecam_bind then UI.freecam_on(not F.freecam_on)
		elseif k == F.shiftlock_bind then UI.shiftlock(not F.shiftlock)
		elseif k == F.fly_bind then UI.fly_on(not F.fly_on)
		elseif k == F.aim_bind then UI.aim_on(not F.aim_on)
		elseif k == F.esp_bind then UI.esp_on(not F.esp_on)
		elseif k == F.noclip_bind then UI.noclip(not F.noclip) end
	elseif i.UserInputType == Enum.UserInputType.MouseButton1 and F.clicktp and not gp and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local _, _, hrp = myParts()
		local hit = LP:GetMouse().Hit
		if hrp and hit then hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
	end
end)

conn(Players.PlayerAdded, function(p) if F.join_alerts then notify(p.DisplayName .. " joined") end; task.wait(0.5); pcall(genv.__AmbienceRefreshPlayers); pcall(genv.__AmbienceRefreshFriends) end)
conn(Players.PlayerRemoving, function(p) if F.join_alerts then notify(p.DisplayName .. " left") end; task.wait(0.2); pcall(genv.__AmbienceRefreshPlayers); pcall(genv.__AmbienceRefreshFriends) end)

----------------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------------
genv.AmbienceUnload = function()
	alive = false
	pcall(function() RS:UnbindFromRenderStep("AmbienceAim") end)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(genv.__AmbienceClean)
	pcall(function() if G.slRestore then G.slRestore() end end)
	pcall(function() if genv.__AmbienceFreecam then genv.__AmbienceFreecam(false) end end)
	if G.avCleanup then pcall(G.avCleanup) end
	pcall(function()
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local o = hum and Orig.hum[hum]
		if o then hum.WalkSpeed = o.ws; hum.UseJumpPower = o.ujp; hum.JumpPower = o.jp; hum.AutoRotate = o.ar end
		if hum then Cam.CameraSubject = hum end
	end)
	for part, v in pairs(hbOrig) do pcall(function() part.Size, part.Transparency, part.CanCollide = v[1], v[2], v[3] end) end
	pcall(function() workspace.Gravity = Orig.gravity; Cam.FieldOfView = Orig.fov end)
	pcall(function() for k, v in pairs(Orig.light) do Lighting[k] = v end end)
	pcall(resetSky)
	for _, n in ipairs({ "AmbienceBloom", "AmbienceRays", "AmbienceCC" }) do pcall(lightFxOff, n) end
	pcall(applyGameFont, "Default")
	if FontState.mconn then pcall(function() FontState.mconn:Disconnect() end) end
	pcall(function() G.blur:Destroy() end)
	pcall(function() G.OV:Destroy() end)
	pcall(function() G.Gui:Destroy() end)
	genv.AmbienceUnload, genv.__AmbienceClean, genv.__AmbienceRefreshPlayers, genv.__AmbienceRefreshFriends, genv.__AmbienceRebuildWP, genv.__AmbienceSpyLog, genv.__AmbienceReset = nil, nil, nil, nil, nil, nil, nil
end

----------------------------------------------------------------------
-- BOOT  (no startup card: straight into the detected profile)
----------------------------------------------------------------------
buildTabs()
local Defaults = {}
for k, v in pairs(F) do if type(v) ~= "table" then Defaults[k] = v end end
genv.__AmbienceReset = function()
	for k, v in pairs(Defaults) do if UI[k] and k ~= "menukey" and k ~= "spy_on" then pcall(UI[k], v) end end
	notify("Reset to defaults")
end
applyMode("Dark")
UI.hue(266)
UI.fx("Stars")
pcall(genv.__AmbienceRefreshPlayers); pcall(genv.__AmbienceRefreshFriends); pcall(genv.__AmbienceRebuildWP)
selectTab("Home")
G.Holder.Visible = true
setOpen(true)
if F.cfg_auto then loadCfg("Default") end
task.delay(0.8, function() if alive then notify("Ambience loaded · " .. Profile.name) end end)
