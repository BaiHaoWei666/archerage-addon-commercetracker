-- 使用真正的路線查詢、結果事件與主視窗邏輯；只替代遊戲 API 和繪圖元件。
local function Noop() end
local events, widgets = {}, {}
local requestSucceeds = true
local materialPrice = 100
local icons, lines = {}, {}
local Widget = {}
Widget.__index = Widget

for _, method in ipairs({
    "AddAnchor", "RemoveAllAnchors", "SetCloseOnEscape", "EnableDrag", "Enable",
    "SetHeight", "SetStartAnimation", "StartMoving", "StopMovingOrSizing",
}) do
    Widget[method] = Noop
end
function Widget:SetExtent(width, height) self.width, self.height = width, height end
function Widget:SetHandler(event, handler) self.handlers[event] = handler end
function Widget:IsVisible() return self.visible end
function Widget:SetVisible(visible) self.visible = visible end
function Widget:SetText(text) self.text = text end
function Widget:SetOptions(options) self.options = options end
function Widget:Select(value) self.value = value end
function Widget:Show(visible)
    local wasVisible = self.visible
    self.visible = visible
    if visible and not wasVisible and self.handlers.OnShow then
        self.handlers.OnShow(self)
    end
end
local function NewWidget(id)
    local widget = setmetatable({ visible = false, handlers = {}, style = { SetColor = Noop } }, Widget)
    if type(id) == "string" then widgets[id] = widget end
    return widget
end

CreateEmptyWindow, SettingWindowSkin = NewWidget, Noop
ALIGN_CENTER, ALIGN_RIGHT = 1, 2
ADDON = { ImportAPI = Noop }
API_TYPE = { STORE = { id = 1 }, CRAFT = { id = 2 }, ABILITY = { id = 3 }, LOCALE = { id = 4 } }
UIEVENT_TYPE = { SPECIALTY_RATIO_BETWEEN_INFO = "ratio" }
UIParent = { SetEventHandler = function(_, event, handler) events[event] = handler end }
X2Locale = { GetLocale = function() return "zh_cn" end }
X2Store = { GetSpecialtyRatioBetween = function() return requestSucceeds end }
X2Ability = { GetAllMyActabilityInfos = function() return {} end }
local materialCounts = { [6215] = 3, [6238] = 2, [9610] = 2, [7784] = 4, [11035] = 4 }
X2Craft = {
    GetCraftMaterialInfo = function(_, craft)
        local materials = {}
        for index = 1, assert(materialCounts[craft]) do
            materials[index] = { item_info = { name = "材料" .. index }, amount = 1 }
        end
        return materials
    end,
}
CT = {
    Chat = Noop, UI = {}, Favorites = { Show = Noop },
    Auction = { Cancel = Noop, PriceOf = function() return materialPrice end },
}
for _, name in ipairs({
    "CreateCaption", "CreateText", "CreateTextButton", "CreateResetButton",
    "CreateCurrency", "CreateIcon", "CreateLine",
}) do
    CT.UI[name] = function(_, id) return NewWidget(id) end
end
CT.UI.CreateIcon = function()
    local icon = NewWidget()
    icons[#icons + 1] = icon
    return icon
end
CT.UI.CreateLine = function()
    local line = NewWidget()
    lines[#lines + 1] = line
    return line
end
CT.UI.CreateComboBox = function(_, id)
    local widget = NewWidget(id)
    widget.trigger = NewWidget()
    return widget
end
CT.UI.SetCurrencyColor, CT.UI.SetIconTexture = Noop, Noop
CT.UI.HideCurrency = function(currency) currency.visible = false end
CT.UI.ShowCurrency = function(_, currency, x, y, amount)
    currency.visible = amount ~= 0
    currency.amount = amount
end
dofile("locale.lua")
dofile("data/zones.lua")
dofile("data/specialties.lua")
dofile("data/prices.lua")
dofile("trade.lua")
dofile("windows/main_window.lua")

local window = CT.MainWindow.window
local function CheckHeight(expected, reason)
    assert(window.width == 800)
    assert(window.height == expected,
        string.format("%s：預期高度 %d，實際 %d", reason, expected, window.height))
end
local function Entry(name, ratio)
    return { itemInfo = { name = name }, ratio = ratio or 124 }
end
local routeResult = {
    Entry("Mahadevi Fine Gilda Specialty"), Entry("Mahadevi Fine Specialty"),
    Entry("Mahadevi Fine Local Specialty"), Entry("Mahadevi Fine Fertilizer Specialty"),
    Entry("Mahadevi Pack"), Entry("Mahadevi Fine Aged Honey"),
    Entry("Mahadevi Fine Aged Cheese"), Entry("Mahadevi Fine Aged Salve"),
}
local function CheckPackVisibility(index, returnsVisible)
    local prefix = "ctPack" .. index
    local pack = CT.Trade.packs[index]
    assert(widgets[prefix .. "Name"].visible, "重新整理應保留品項名稱")
    assert(icons[index].visible, "重新整理應保留品項圖示")
    assert(lines[1].visible and lines[index + 1].visible, "重新整理應保留分隔線")
    assert(widgets[prefix .. "Ratio"].visible == returnsVisible, "百分比顯示狀態錯誤")
    assert(widgets[prefix .. "Sale"].visible == returnsVisible, "預測報酬金顯示狀態錯誤")
    if pack.isSpecialty then
        assert(widgets[prefix .. "Profit"].visible == returnsVisible, "收益顯示狀態錯誤")
        assert(widgets[prefix .. "PackCost"].visible, "重新整理應保留總成本")
        for materialIndex in ipairs(pack.materials) do
            local id = prefix .. "Mat" .. materialIndex
            assert(widgets[id].visible and widgets[id .. "Cost"].visible,
                "重新整理應保留材料與材料成本")
        end
    end
end
local function RefreshRoute()
    local previousPacks = CT.Trade.packs
    CT.Trade.Tick(6000)
    widgets.ctRefresh.handlers.OnClick()
    assert(CT.Trade.packs == previousPacks, "重新整理應保留既有清單")
    for index in ipairs(previousPacks) do
        CheckPackVisibility(index, not requestSucceeds)
    end
end

CheckHeight(575, "建立視窗")
CT.MainWindow.Toggle()
CheckHeight(575, "首次開啟空視窗")
widgets.ctContinentCombo.onSelect("Haranya")
widgets.ctFromCombo.onSelect(9)
CheckHeight(575, "尚未選齊路線")
widgets.ctToCombo.onSelect(4)
CheckHeight(575, "首次查詢等待結果")
events.ratio(routeResult)
CheckHeight(750, "依八個品項與材料展開")
assert(widgets.ctPack1Name.visible and widgets.ctPack1Mat1.visible)
CheckPackVisibility(1, true)
CheckPackVisibility(6, true)
CT.MainWindow.Toggle()
CT.MainWindow.Toggle()
CheckHeight(750, "重新開啟已有資料的視窗")

RefreshRoute()
CheckHeight(750, "重新查詢保留目前高度")
-- 冷卻結束、額外重畫或關閉再開啟，都不能提早顯示尚待更新的數值。
CT.Trade.Tick(6000)
materialPrice = 200
CT.MainWindow.Refresh()
CheckPackVisibility(1, false)
assert(widgets.ctPack1Mat1Cost.amount == 200 and widgets.ctPack1PackCost.amount == 600)
CT.MainWindow.Toggle()
CT.MainWindow.Toggle()
CheckHeight(750, "等待期間重新開啟")
CheckPackVisibility(1, false)
CheckPackVisibility(6, false)
events.ratio({ Entry("Mahadevi Fine Gilda Specialty", 127) })
CheckHeight(250, "收到較少品項仍應縮至內容高度")
CheckPackVisibility(1, true)
assert(widgets.ctPack1Ratio.text == "127%")
assert(widgets.ctPack1Sale.amount == CT.Trade.SalePrice(CT.Trade.packs[1]))
assert(widgets.ctPack1Profit.amount == widgets.ctPack1Sale.amount - 600)
assert(not widgets.ctPack2Name.visible, "縮短清單後應隱藏多餘品項")

-- 查詢失敗時恢復原有數值，不讓三個欄位一直維持隱藏。
RefreshRoute()
events.ratio(nil)
CheckPackVisibility(1, true)
assert(widgets.ctPack1Ratio.text == "127%")
requestSucceeds = false
RefreshRoute()
CheckPackVisibility(1, true)
requestSucceeds = true

RefreshRoute()
events.ratio({})
CheckHeight(250, "空結果保留目前高度")
RefreshRoute()
events.ratio(nil)
CheckHeight(250, "無效結果保留目前高度")
requestSucceeds = false
RefreshRoute()
CheckHeight(250, "查詢未送出仍保留目前高度")
requestSucceeds = true
RefreshRoute()
events.ratio(routeResult)
CheckHeight(750, "查詢恢復後重新展開")

-- 換交貨區域屬於另一條路線，等待時必須隱藏舊品項與材料。
CT.Trade.Tick(6000)
widgets.ctToCombo.onSelect(12)
assert(#CT.Trade.packs == 0)
assert(not widgets.ctPack1Name.visible and not widgets.ctPack1Mat1.visible)
assert(not icons[1].visible and not lines[2].visible)
CheckHeight(750, "切換交貨區域保留高度")
events.ratio(routeResult)

-- 收藏可在冷卻期間切換路線，不能讓保留的清單被當成新路線內容。
RefreshRoute()
CT.MainWindow.ApplyRoute("Haranya", 9, 17)
assert(#CT.Trade.packs == 0, "冷卻期間切換收藏也應清除舊路線")
assert(not widgets.ctPack1Name.visible and not widgets.ctPack1Mat1.visible)
events.ratio(routeResult)
assert(#CT.Trade.packs == 0, "已清除路線的延遲結果不應重新出現")
RefreshRoute()
events.ratio(routeResult)
CheckPackVisibility(1, true)

CT.Trade.Tick(6000)
widgets.ctContinentCombo.onSelect("Nuia")
CheckHeight(750, "切換大陸保留目前高度")
assert(#CT.Trade.packs == 0 and not widgets.ctPack1Name.visible)
assert(not widgets.ctPack1Mat1.visible)
CT.MainWindow.Toggle()
CT.MainWindow.ApplyRoute("Haranya", 9, 4)
CheckHeight(750, "從收藏開啟並等待查詢")
events.ratio({ Entry("Mahadevi Fine Gilda Specialty") })
CheckHeight(250, "收藏路線結果依內容調整")

print("PASS: 主視窗高度、重新整理只隱藏三個欄位、查詢失敗恢復與路線切換")
