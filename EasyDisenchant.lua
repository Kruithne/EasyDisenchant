-- [[ Globals ]] --
local PlaySound = PlaySound;
local HideUIPanel = HideUIPanel;
local math_floor = math.floor;
local string_find = string.find;

local _K = Krutilities;
local _M = {
	addonName = "EasyDisenchant",
	chatFormat = "EasyDisenchant: %s",
	eventFrame = CreateFrame("FRAME"),
	itemButtons = {},
	eventMap = {}, -- Used for internal mapping of events.
	isTradeSkillFrameHooked = false,
	tradeSkillID = 333, -- CHARACTER_PROFESSION_ENCHANTING
	maxButtons = 89,
	buttonRenderingCache = {},
};

BINDING_HEADER_EASY_DISENCHANT = _M.addonName;
BINDING_NAME_EASY_DISENCHANT_OPEN = SHOW;

_M.GetItemIDFromLink = function(itemLink)
	return string_find(itemLink, "Hitem:(%d+)");
end

_M.IsBlacklisted = function(self, itemID)
	return self.blacklist[itemID];
end

_M.BlacklistItem = function(self, itemLink)
	local itemID = self.GetItemIDFromLink(itemLink);

	if itemID then
		self.blacklist[itemID] = true;
		self.lastBlacklistedItem = itemID;
		self.lastBlacklistedItemLink = itemLink;

		self:Print(itemLink .. " has been blacklisted.");
		self:Print("Use the command /de undo to revert this, or /de reset to remove all blacklisted items.");
	end
end

_M.ResetBlacklist = function(self)
    self.blacklist = {};
	self:Print("Item blacklist has been reset.");
end

_M.UndoBlacklist = function(self)
	if self.lastBlacklistedItem and self:IsBlacklisted(self.lastBlacklistedItem) then
		self.blacklist[self.lastBlacklistedItem] = nil;
		self:Print("Removed " .. self.lastBlacklistedItemLink .. " from the blacklist.");

		self.lastBlacklistedItem = nil;
		self.lastBlacklistedItemLink = nil;
	end
end

_M.Print = function(self, message)
	DEFAULT_CHAT_FRAME:AddMessage(self.chatFormat:format(message));
end

_M.SetEventHandler = function(self, event, func)
	self.eventMap[event] = func;
	self.eventFrame:RegisterEvent(event);
end

_M.RemoveEventHandler = function(self, event)
	self.eventMap[event] = nil;
	self.eventFrame:UnregisterEvent(event);
end

_M.HookTradeSkillFrame = function(self)
	self:SetEventHandler("TRADE_SKILL_DATA_SOURCE_CHANGED", _M.CheckTradeSkillButton);
	self.isTradeSkillFrameHooked = true;
end

_M.CreateTradeSkillButton = function(self)
	self.tradeSkillButton = _K:Frame({
		name = "EasyDisenchantTradeSkillButton",
		parent = TradeSkillFrame,
		enableMouse = true,
		size = {256, 78},
		points = {
			point = "TOPRIGHT",
			relativePoint = "BOTTOMRIGHT",
		},
		textures = {
			{
				texture = [[Interface\Transmogrify\TransmogToast]],
				texCoord = {0, 1, 0, 0.609375}
			},
			{
				texture = [[Interface\ICONS\INV_Enchant_Disenchant]],
				subLevel = -1,
				size = 45,
				points = {
					point = "LEFT", x = 15,
				}
			}
		},
		texts = {
			text = "EasyDisenchant",
			inherit = "GameFontHighlight",
			points = {
				point = "LEFT", x = 72
			}
		},
		scripts = {
			OnMouseUp = self.InvokeWindowOpen
		}
	});
end

_M.CheckTradeSkillButton = function(self)
	if C_TradeSkillUI.GetTradeSkillLine() == self.tradeSkillID then
		if not self.tradeSkillButton then
			self:CreateTradeSkillButton();
		end

		self.tradeSkillButton:Show();
	else
		if self.tradeSkillButton then
			self.tradeSkillButton:Hide();
		end
	end
end

_M.GetItemButtonRenderingCache = function(self)
	local cache = self.buttonRenderingCache;
	if not cache.hasCreated then
		local frame = self.disenchantFrame;

		-- Called when an item button is clicked, as a post-event.
		cache.func_clickHook = function(self, key)
			if InCombatLockdown() then
				frame.header:SetText(ERR_NOT_IN_COMBAT);
				frame.header:SetTextColor(1, 0, 0);
			else
                if(key == "RightButton")then
                    _M:BlacklistItem(self.link);
                end
				self:Hide();
			end
		end

		-- Called when the player's cursor leaves an item button.
		cache.func_mouseLeave = function(self)
			frame.glow:Hide();
			GameTooltip:Hide();
		end

		-- Called when the player's cursor enters an item button.
		cache.func_mouseEnter = function(self)
			frame.glow:SetPoint("CENTER", self);
			frame.glow:Show();

			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			GameTooltip:SetHyperlink(self.link);
			GameTooltip:Show();
		end

		cache.factory = function(index)
			return {
				type = "BUTTON",
				parent = self.disenchantFrame,
				parentName = "ItemButton" .. index,
				inherit = "ItemButtonTemplate,SecureActionButtonTemplate",
				textures = {
					injectSelf = "backdrop",
					layer = "BACKGROUND",
					texture = [[Interface\Buttons\UI-EmptySlot-Disabled]],
					size = 54,
				},
				points = {
					point = "TOPLEFT",
					x = 38 + (38 * (index % 9)),
					y = -73 + (math_floor(index / 9) * -38)
				},
				scripts = {
					OnEnter = cache.func_mouseEnter,
					OnLeave = cache.func_mouseLeave
				},
			};
		end

		-- Prevent this scope being run again.
		cache.hasCreated = true;
	end
	return cache;
end

_M.GetItemButton = function(self, index)
	local buttons = self.itemButtons;
	if buttons[index + 1] then
		return buttons[index + 1];
	end

	local cache = self:GetItemButtonRenderingCache();
	local button = _K:Frame(cache.factory(index));

	button:HookScript("OnClick", cache.func_clickHook);
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	button:SetAttribute("type", "macro");

	buttons[#buttons + 1] = button;
	return button;
end

_M.UpdateItems = function(self)
	-- Hide buttons.
	local buttons = _M.itemButtons;
	local nButtons = #buttons;

	for i = 1, nButtons do
		buttons[i]:Hide();
	end

	local disenchantName = GetSpellInfo(13262);
	local macroFormat = "/stopmacro [combat][btn:2]\n/stopcasting\n/cast %s\n/cast %s %s";

	local useButton = 0;
	for bagID = 0, NUM_BAG_SLOTS do
		for slotID = 1, GetContainerNumSlots(bagID) do
			local itemTexture, _, _, itemQuality, _, _, itemLink = GetContainerItemInfo(bagID, slotID);

			-- Skip non-existant items or legendary+.
			if itemLink ~= nil and (itemQuality ~= nil and itemQuality < 5 and itemQuality > 1) then
				local itemName, _, _, _, _, itemClass, itemSubClass = GetItemInfo(itemLink);

				-- Avoid breaking on M+ keys
                if itemSubClass ~= nil then
                    -- Check Blacklist
					local itemID = self:GetItemIDFromLink(itemLink);
                    if not self:IsBlacklisted(itemID) then
                        -- Only disenchant weapons and armour.
                        if itemClass == WEAPON or itemClass == ARMOR or itemSubClass:find(ITEM_QUALITY6_DESC) then
                            local button = self:GetItemButton(useButton);

                            SetItemButtonTexture(button, itemTexture);
                            SetItemButtonQuality(button, itemQuality, itemLink);

                            button:SetAttribute("macrotext", macroFormat:format(disenchantName, bagID, slotID));
                            button.link = itemLink;
                            button:Show();

                            if useButton == self.maxButtons then
                                return;
                            end

                            useButton = useButton + 1;
                        end
                    end
                end
			end
		end
	end
end

_M.CreateDisenchantFrame = function(self)
	local bgAnchor = {
		{ point = "TOPLEFT", x = 8, y = -8 },
		{ point = "BOTTOMRIGHT", x = -8, y = 8 }
	};

	local cornerMixin = {
		layer = "BACKGROUND",
		size = 64,
		subLevel = -2,
		texture = [[Interface\Transmogrify\Textures]]
	};

	local edgeXMixin = {
		tileX = true,
		subLevel = -3,
		size = {64, 23},
		layer = "BACKGROUND",
		texture = [[Interface\Transmogrify\HorizontalTiles]]
	};

	local edgeYMixin = {
		tileY = true,
		subLevel = -3,
		size = {23, 64},
		layer = "BACKGROUND",
		texture = [[Interface\Transmogrify\VerticalTiles]]
	};

	self.disenchantFrame = _K:Frame({
		name = "EasyDisenchantFrame",
		size = {418, 472},
		frames = {
			{ -- Close Button
				type = "BUTTON",
				parentName = "CloseButton",
				inherit = "UIPanelCloseButton",
				points = { point = "TOPRIGHT", x = -20, y = -25 }
			},
			{ -- Glow used by the item buttons.
				size = 37,
				hidden = true,
				injectSelf = "glow",
				textures = {
					{
						parentName = "InnerGlow", injectSelf = "innerGlow",
						texture = [[Interface\SpellActivationOverlay\IconAlert]],
						size = 53, points = { point = "CENTER" },
						texCoord = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }
					},
					{
						layer = "OVERLAY", parentName = "Ants", injectSelf = "ants",
						texture = [[Interface\SpellActivationOverlay\IconAlertAnts]],
						size = 44, points = { point = "CENTER" }
					}
				},
				scripts = {
					OnUpdate = function(self, elapsed) AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, 0.01); end
				}
			}
		},
		texts = {
			inherit = "GameFontHighlightMedium",
			text = "EasyDisenchant",
			injectSelf = "header",
			points = { point = "TOPLEFT", x = 35, y = -40 }
		},
		textures = {
			{ -- Background.
				layer = "BACKGROUND",
				subLevel = -6,
				texture = [[Interface\FrameGeneral\UI-Background-Marble]],
				tile = true,
				points = bgAnchor,
				color = {0.302, 0.102, 0.204, 0.8}
			},
			{ -- Corner: Top Left
				parentName = "CornerTL",
				mixin = cornerMixin,
				points = "TOPLEFT",
				texCoord = {0.00781250, 0.50781250, 0.00195313, 0.12695313}
			},
			{ -- Corner: Top Right
				parentName = "CornerTR",
				mixin = cornerMixin,
				points = "TOPRIGHT", 
				texCoord = {0.00781250, 0.50781250, 0.38476563, 0.50781250}
			},
			{ -- Corner: Bottom Left
				parentName = "CornerBL",
				mixin = cornerMixin,
				points = "BOTTOMLEFT",
				texCoord = {0.0078125, 0.5078125, 0.2578125, 0.38085938}
			},
			{ -- Corner: Bottom Right
				parentName = "CornerBR",
				mixin = cornerMixin,
				points = "BOTTOMRIGHT",
				texCoord = {0.0078125, 0.5078125, 0.13085938, 0.25390625}
			},
			{ -- Edge: Top
				parentName = "TopEdge",
				mixin = edgeXMixin,
				points = {
					{ point = "TOPLEFT", relativeTo = "$parentCornerTL", relativePoint = "TOPRIGHT", x = -30, y = -5 },
					{ point = "TOPRIGHT", relativeTo = "$parentCornerTR", relativePoint = "TOPLEFT", x = 30, y = -5 }
				},
				texCoord = {0, 1, 0.40625, 0.765625}
			},
			{ -- Edge: Bottom
				parentName = "BottomEdge",
				mixin = edgeXMixin,
				points = {
					{ point = "BOTTOMLEFT", relativeTo = "$parentCornerBL", relativePoint = "BOTTOMRIGHT", x = -30, y = 4 },
					{ point = "BOTTOMRIGHT", relativeTo = "$parentCornerBR", relativePoint = "BOTTOMLEFT", x = 30, y = 4 }
				},
				texCoord = {0, 1, 0.015625, 0.375}
			},
			{ -- Edge: Left
				parentName = "LeftEdge",
				mixin = edgeYMixin,
				points = {
					{ point = "TOPLEFT", relativeTo = "$parentCornerTL", relativePoint = "BOTTOMLEFT", x = 4, y = 16 },
					{ point = "BOTTOMLEFT", relativeTo = "$parentCornerBL", relativePoint = "TOPLEFT", x = 4, y = -16 }
				},
				texCoord = {0.40625, 0.765625, 0, 1}
			},
			{ -- Edge: Right
				parentName = "RightEdge",
				mixin = edgeYMixin,
				points = {
					{ point = "TOPRIGHT", relativeTo = "$parentCornerTR", relativePoint = "BOTTOMRIGHT", x = -4, y = 16 },
					{ point = "BOTTOMRIGHT", relativeTo = "$parentCornerBR", relativePoint = "TOPRIGHT", x = -4, y = -16 }
				},
				texCoord = {0.015625, 0.375, 0, 1}
			}
		},
		scripts = {
			OnHide = function() PlaySound(SOUNDKIT.UI_ETHEREAL_WINDOW_CLOSE); end
		}
	});
end

_M.OpenWindow = function(self)
	HideUIPanel(TradeSkillFrame);

	if not self.disenchantFrame then
		self:CreateDisenchantFrame();
	end

	self:UpdateItems();
	self.disenchantFrame:Show();
	PlaySound(SOUNDKIT.UI_ETHEREAL_WINDOW_OPEN);
end

_M.OnLoad = function(self)
	-- Register command.
	SLASH_DISENCHANT1, SLASH_DISENCHANT2 = "/disenchant", "/de";
	SlashCmdList["DISENCHANT"] = 
    function(msg)
        -- if command is /disenchant reset or /de reset; reset the blacklist.
        if(strlower(msg) == "reset") then
            self:ResetBlacklist();
            return;
        end
        -- if command is /disenchant undo or /de undo; remove last item from blacklist
        if(strlower(msg) == "undo") then
			self:UndoBlacklist();
            return;
        end
        self.InvokeWindowOpen();
    end

	-- Created store blacklist table if it doesn't exist.
	if not EasyDisenchantBlacklist then
		EasyDisenchantBlacklist = {};
	end

	-- Store local reference to our stored table.
	self.blacklist = EasyDisenchantBlacklist;

	-- Hook to TradeSkillFrame.
	if not self.isTradeSkillFrameHooked and IsAddOnLoaded("Blizzard_TradeSkillUI") then
		self:HookTradeSkillFrame();
	end
end

_M.OnEvent = function(self, event, ...)
	-- Note: self is not _M in this instance, it's eventFrame.
	local handler = _M.eventMap[event];
	if handler then
		handler(_M, ...);
	end
end

_M.InvokeWindowOpen = function()
	_M:OpenWindow();
end

_M.OnAddonLoaded = function(self, addonName)
	if addonName == self.addonName then
		self:OnLoad();
	elseif addonName == "Blizzard_TradeSkillUI" then
		_M:HookTradeSkillFrame();
	end
end

_M.eventFrame:SetScript("OnEvent", _M.OnEvent);
_M:SetEventHandler("ADDON_LOADED", _M.OnAddonLoaded);

-- Global handle to open the window.
EasyDisenchantShowWindow = _M.InvokeWindowOpen;
