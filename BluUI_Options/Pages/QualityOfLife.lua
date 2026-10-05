local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local CARD_HEIGHT = 160
local BODY_Y = 42

local function Window()
	return BUI.PageEngine.window
end

local function Sections(_, _, parent, width)
	local cards = Layout.CardKit(Window())
	local host = CreateFrame('Frame', nil, parent)
	host:SetSize(width, CARD_HEIGHT)
	local card = cards.Card(host, 0, 0, width, CARD_HEIGHT)
	cards.Title(card, 'Coming soon')
	cards.Description(card, 'Small helpers that smooth out everyday play will live here. Nothing to set up yet.', cards.PAD, BODY_Y, width - cards.PAD * 2)
	function host:Layout(y)
		self:ClearAllPoints()
		self:SetPoint('TOPLEFT', 0, -y)
		return y + CARD_HEIGHT
	end
	return { host }
end

BUI.PageEngine.RegisterPage('qol', {
	title = 'Quality of life',
	buttonText = 'Quality of life',
	icon = 'plus',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'plus',
			title = 'Quality of life',
			placeholder = 'Search quality of life settings...',
			tabs = { { label = 'Coming soon', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
