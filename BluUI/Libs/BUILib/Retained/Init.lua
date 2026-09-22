local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end

local Retained = BUILib.R or {}
BUILib.R = Retained

Retained.types = Retained.types or {}

Retained.holdingFrame = Retained.holdingFrame or CreateFrame("Frame", nil, UIParent)
Retained.holdingFrame:Hide()

Retained._framesCreated = Retained._framesCreated or 0
