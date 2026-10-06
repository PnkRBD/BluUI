local _, BUI = ...
local Pixel = BUI.Pixel
local FONT = BluUI.BUILibClient.Font

local PrivateWarning = {}
BUI.Auras.PrivateWarning = PrivateWarning

local FRAME_NAME = 'BUI_PrivateWarning'
local WIDTH, HEIGHT = 800, 80
local SAMPLE_TEXT = 'Private raid warning'

local holder, lockListener

local function GetDB() return BUI.GetDB().privateWarning end

local function Bind(parent)
	C_UnitAuras.SetPrivateWarningTextAnchor(parent, { point = 'TOP', relativeTo = parent, relativePoint = 'TOP', offsetX = 0, offsetY = 0 })
end

local function Build()
	if holder then return end
	holder = CreateFrame('Frame', FRAME_NAME, UIParent)
	holder:SetSize(WIDTH, HEIGHT)
	holder:SetFrameStrata('HIGH')
	holder.sample = holder:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(holder.sample, 22, FONT, 'OUTLINE')
	holder.sample:SetPoint('TOP', 0, -Pixel.Scale(8))
	holder.sample:SetText(SAMPLE_TEXT)
	holder.sample:Hide()
	BUI.Dragging.MakeAnchoredAlert(holder, {
		settings = GetDB,
		isLocked = function() return GetDB().locked end,
		onRightClick = function() PrivateWarning.SetLocked(true) end,
	})
end

local function Apply()
	local db = GetDB()
	BUI.Anchor.ApplyPosition(holder, db)
	holder:SetScale(db.scale / 100)
	Bind(holder)
end

local function PaintLock(locked)
	BUI.Dragging.SetLocked(holder, locked)
	holder:EnableMouse(not locked)
	holder.sample:SetShown(not locked)
end

function PrivateWarning.Enable()
	Build()
	holder:Show()
	Apply()
end

function PrivateWarning.Disable()
	if PrivateRaidBossEmoteFrameAnchor then Bind(PrivateRaidBossEmoteFrameAnchor) end
	if holder then holder:Hide() end
end

function PrivateWarning.SetLockListener(callback)
	lockListener = callback
end

function PrivateWarning.SetLocked(locked)
	local db = GetDB()
	db.locked = locked
	if lockListener then lockListener() end
	if not db.enabled then return end
	PrivateWarning.Enable()
	PaintLock(locked)
end

function PrivateWarning.Refresh()
	local db = GetDB()
	if not db.enabled then
		PrivateWarning.Disable()
		return
	end
	PrivateWarning.Enable()
	PaintLock(db.locked)
end

BUI.Events:OnLogin('PrivateWarning', function()
	if GetDB().enabled then PrivateWarning.Enable() end
end, 'auras')
