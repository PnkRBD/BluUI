local _, BUI = ...

local InCombatLockdown = InCombatLockdown

local SecureRelay = {}
BUI.SecureRelay = SecureRelay

local BUTTON_SUFFIX = { LeftButton = '1', RightButton = '2' }
local ACTION_KEY = { macro = 'macrotext', click = 'clickbutton' }
local LEVEL_ABOVE = 20
local HIDE_IN_COMBAT = [[ if name == 'state-combat' and value == '1' then self:Hide() end ]]

local specs = setmetatable({}, { __mode = 'k' })
local relay, current, propagates

local function RunScript(host, script, ...)
	local handler = host:GetScript(script)
	if handler then handler(host, ...) end
end

local function Release()
	if not relay or InCombatLockdown() then return end
	relay:Hide()
end

local function RelayEnter()
	if current and not propagates then RunScript(current, 'OnEnter') end
end

local function RelayLeave()
	local host = current
	Release()
	if host and not propagates then RunScript(host, 'OnLeave') end
end

local function RelayClick(_, button, down)
	local host = current
	if host and not down then RunScript(host, specs[host].forward or 'OnClick', button) end
end

local function RelayDragStart()
	local host = current
	if not host or not host:GetScript('OnDragStart') then return end
	relay:SetAttribute('type1', nil)
	relay:SetAttribute('type2', nil)
	RunScript(host, 'OnDragStart')
end

local function RelayDragStop()
	local host = current
	if not host or not host:GetScript('OnDragStop') then return end
	RunScript(host, 'OnDragStop')
	Release()
end

local function RelayHidden()
	current = nil
end

local function Build()
	relay = CreateFrame('Button', 'BUI_SecureRelay', UIParent, 'SecureActionButtonTemplate, SecureHandlerAttributeTemplate')
	relay:RegisterForClicks('AnyDown', 'AnyUp')
	relay:RegisterForDrag('LeftButton')
	propagates = relay.SetPropagateMouseMotion ~= nil
	if propagates then relay:SetPropagateMouseMotion(true) end
	relay:SetAttribute('_onattributechanged', HIDE_IN_COMBAT)
	RegisterAttributeDriver(relay, 'state-combat', '[combat] 1; 0')
	relay:SetScript('OnEnter', BUI.Profiler.Script('SecureRelay OnEnter', RelayEnter))
	relay:SetScript('OnLeave', BUI.Profiler.Script('SecureRelay OnLeave', RelayLeave))
	relay:SetScript('PostClick', BUI.Profiler.Script('SecureRelay PostClick', RelayClick))
	relay:SetScript('OnDragStart', BUI.Profiler.Script('SecureRelay OnDragStart', RelayDragStart))
	relay:SetScript('OnDragStop', BUI.Profiler.Script('SecureRelay OnDragStop', RelayDragStop))
	relay:HookScript('OnHide', BUI.Profiler.Wrap('SecureRelay hidden', RelayHidden))
	relay:Hide()
end

local function Configure(spec, host)
	local kind, value = spec.action(host)
	if not kind or not value then return false end
	relay:SetAttribute('type1', nil)
	relay:SetAttribute('type2', nil)
	local suffix = BUTTON_SUFFIX[spec.button or 'LeftButton']
	relay:SetAttribute('type' .. suffix, kind)
	relay:SetAttribute(ACTION_KEY[kind] .. suffix, value)
	return true
end

local function Place(spec, host)
	local left, bottom, width, height = host:GetRect()
	if not left or width <= 0 or height <= 0 then return false end
	local scale = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
	relay:ClearAllPoints()
	relay:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left * scale, bottom * scale)
	relay:SetSize(width * scale, height * scale)
	relay:SetFrameStrata(host:GetFrameStrata())
	relay:SetFrameLevel(host:GetFrameLevel() + (spec.level or LEVEL_ABOVE))
	return true
end

local function HostEnter(host)
	if InCombatLockdown() or current == host then return end
	local spec = specs[host]
	if not spec then return end
	if not relay then Build() end
	if not Configure(spec, host) or not Place(spec, host) then return end
	current = host
	relay:Show()
end

local function HostHidden(host)
	if current == host then Release() end
end

function SecureRelay.Attach(host, spec)
	local hooked = specs[host] ~= nil
	specs[host] = spec
	if hooked then return end
	host:HookScript('OnEnter', BUI.Profiler.Wrap('SecureRelay host OnEnter', HostEnter))
	host:HookScript('OnHide', BUI.Profiler.Wrap('SecureRelay host OnHide', HostHidden))
end

function SecureRelay.Slash(command)
	local text = _G['SLASH_' .. command .. '1']
	if text then return 'macro', text end
end
