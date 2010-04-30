--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local containerProto = setmetatable({}, { __index = CreateFrame("Frame") })
local containerMeta = { __index = containerProto }
local containerCount = 1
LibStub('AceEvent-3.0'):Embed(containerProto)
LibStub('AceBucket-3.0'):Embed(containerProto)

containerProto.Debug = addon.Debug

local ITEM_SIZE = 37
local ITEM_SPACING = 4
local BAG_WIDTH = 10
local BAG_INSET = 8
local TOP_PADDING = 32

local BACKDROP = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
}

function addon:CreateContainerFrame(name, bags, isBank)
	local container = setmetatable(CreateFrame("Frame", addonName..name, UIParent), containerMeta)
	container:Debug('Created')
	container:ClearAllPoints()
	container:EnableMouse(true)
	container:Hide()
	container:OnCreate(name, bags, isBank)
	return container
end

local function CloseButton_OnClick(button)
	button:GetParent():Hide()
end

function containerProto:OnCreate(name, bags, isBank)
	self:SetScale(0.8)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.bags = bags
	self.isBank = isBank
	self.buttons = {}
	self.content = {}
	self.stacks = {}
	for bag in pairs(self.bags) do
		self.content[bag] = {}
	end

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	local closeButton = CreateFrame("Button", self:GetName().."CloseButton", self, "UIPanelCloseButton")
	self.closeButton = closeButton
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', CloseButton_OnClick)

	local title = self:CreateFontString(self:GetName().."Title","OVERLAY","GameFontNormalLarge")
	title:SetText(name)
	title:SetTextColor(1, 1, 1)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	title:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
end

function containerProto:OnShow()
	self:Debug('OnShow')
	if self.isBank then
		self:RegisterEvent('BANKFRAME_CLOSED', "Hide")
	end
	self:RegisterBucketEvent('BAG_UPDATE', 0.1, "BagsUpdated")
	for bag in pairs(self.bags) do
		self:UpdateContent("OnShow", bag)
	end
	return self:FullUpdate('OnShow', true)
end

function containerProto:OnHide()
	self:UnregisterAllEvents()
	self:UnregisterAllBuckets()
end

function containerProto:UpdateContent(event, bag)
	self:Debug('UpdateContent', event, bag)
	local bagContent = self.content[bag]
	bagContent.size = GetContainerNumSlots(bag)
	for slot = 1, bagContent.size do
		local link = GetContainerItemLink(bag, slot)
		if link ~= bagContent[slot] then
			bagContent[slot] = link
			self.dirty = true
		end
	end
	if #bagContent > bagContent.size then
		self.dirty = true
		for slot = bagContent.size+1, #bagContent do
			bagContent[slot] = nil
		end
	end
end

local EQUIP_LOCS = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13,
	INVTYPE_CLOAK = 15,
	INVTYPE_WEAPON = 16,
	INVTYPE_SHIELD = 17,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_HOLDABLE = 17,
	INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18,
	INVTYPE_RANGEDRIGHT = 18,
	INVTYPE_RELIC = 18,
	INVTYPE_TABARD = 19,
	INVTYPE_BAG = 20,
}

local function CompareItems(idA, idB)
	local nameA, _, qualityA, levelA, _, classA, subclassA, _, equipSlotA = GetItemInfo(idA)
	local nameB, _, qualityB, levelB, _, classB, subclassB, _, equipSlotB = GetItemInfo(idB)
	local equipLocA = EQUIP_LOCS[equipSlotA or ""]
	local equipLocB = EQUIP_LOCS[equipSlotB or ""]
	if classA ~= classB then
		return classA < classB
	elseif subclassA ~= subclassB then
		return subclassA < subclassB
	elseif equipLocA and equipLocA and equipLocA ~= equipLocB then
		return equipLocA < equipLocB
	elseif qualityA ~= qualityB then
		return qualityA > qualityB
	elseif levelA ~= levelB then
		return levelA > levelB
	else
		return nameA < nameB
	end
end

local itemCompareCache = setmetatable({}, { 
	__index = function(t, key)
		local idA, idB = strsplit(':', key)
		idA, idB = tonumber(idA), idB
		local result = CompareItems(idA, idB)
		t[key] = result
		return result
	end
})

local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local strformat = string.format

local function CompareButtons(a, b)
	local idA = GetContainerItemID(a.bag, a.slot)
	local idB = GetContainerItemID(b.bag, b.slot)
	if idA and idB then
		if idA ~= idB then
			return itemCompareCache[strformat("%d:%d", idA, idB)]
		else
			local _, countA = GetContainerItemInfo(a.bag, a.slot)
			local _, countB = GetContainerItemInfo(b.bag, b.slot)
			return countA > countB
		end
	elseif not idA and not idB then
		local _, famA = GetContainerNumFreeSlots(a.bag)
		local _, famB = GetContainerNumFreeSlots(b.bag)
		if famA and famB and famA ~= famB then
			return famA < famB
		end
	end
	return (idA and 1 or 0) > (idB and 1 or 0)
end

function containerProto:SetPosition(button, position)
	local col, row = (position-1) % BAG_WIDTH, math.floor((position-1) / BAG_WIDTH)
	button:SetPoint('TOPLEFT', self, 'TOPLEFT',
		BAG_INSET + col * (ITEM_SIZE + ITEM_SPACING),
		- (TOP_PADDING + row * (ITEM_SIZE + ITEM_SPACING))
	)
	button:Show()
end

function containerProto:SetupItemButton(index)
	local button = self.buttons[index]
	if not button then
		button = addon:AcquireItemButton()
		button:SetWidth(ITEM_SIZE)
		button:SetHeight(ITEM_SIZE)
		self.buttons[index] = button
	end
	return button
end

function containerProto:ReleaseItemButton(index)
	local button = self.buttons[index]
	if not button then return end
	self.buttons[index] = nil
	button:Release()
	return true
end

local function IsStackable(bag, slot)
	local id = GetContainerItemID(bag, slot)
	if not id then
		local _, family = GetContainerNumFreeSlots(bag)
		return true, 'free', family
	elseif id == 6265 then
		return true, 'item', id
	end
end

local order = {}
function containerProto:FullUpdate(event, forceUpdate)
	if not self.dirty and not forceUpdate then return end
	self:Debug('Updating on', event)
	self.dirty = nil
	wipe(self.stacks)
	local index = 0
	local reorder = forceUpdate
	for bag, content in pairs(self.content) do
		for slot = 1, content.size do
			local stackable, stackType, stackData = IsStackable(bag, slot)
			local stackKey = stackable and strjoin(':', stackType, stackData)
			if not stackable or not self.stacks[stackKey] then
				index = index + 1
				local button = self:SetupItemButton(index)
				if button:SetBagSlot(bag, slot) then
					reorder = true
				end
				if button:SetStackable(stackable, stackType, stackData) then
					reorder = true
				end
				if stackable then
					self.stacks[stackKey] = button
				end
				tinsert(order, button)
			end
		end
	end
	for unused = index+1, #self.buttons do
		if self:ReleaseItemButton(unused) then
			reorder = true
		end
	end
	if reorder then
		self:Debug('Need reordering')
		table.sort(order, CompareButtons)
		for position, button in ipairs(order) do
			self:SetPosition(button, position)
		end
	end
	self:Debug(#order, 'items')
	wipe(order)
	local cols = math.min(BAG_WIDTH, index)
	local rows = math.ceil(index / BAG_WIDTH)
	self:SetWidth(BAG_INSET * 2 + cols * ITEM_SIZE + math.max(0, cols-1) * ITEM_SPACING)
	self:SetHeight(BAG_INSET + rows * ITEM_SIZE + math.max(0, rows-1) * ITEM_SPACING + TOP_PADDING)
end

function containerProto:BagsUpdated(bags)
	self:Debug('BagsUpdated', bags)
	for bag, x in pairs(bags) do
		self:Debug('-', bag ,x)
		if self.bags[bag] then
			self:UpdateContent(event, bag)
		end
	end
	if self.dirty then
		return self:FullUpdate("BagsUpdated")
	else
		for i, button in pairs(self.buttons) do
			if bags[button.bag] then
				button:FullUpdate("BagsUpdated")
			end
		end
	end
end
