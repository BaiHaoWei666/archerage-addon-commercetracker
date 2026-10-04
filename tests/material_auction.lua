-- 使用正式拍賣模組與材料可交易判斷，只替代遊戲 API。
local function Noop() end

local function Run(locale)
    local events, searches, messages = {}, {}, {}
    local opens = 0
    local openFails, searchFails = false, false
    local auctionResult
    ADDON = {
        ImportAPI = Noop,
        ShowContent = function(_, content, visible)
            assert(content == UIC_AUCTION and visible == true)
            opens = opens + 1
            if openFails then error("模擬開啟失敗") end
        end,
    }
    API_TYPE = {
        STORE = { id = 1 }, CRAFT = { id = 2 }, ABILITY = { id = 3 },
        LOCALE = { id = 4 }, AUCTION = { id = 5 },
    }
    UIC_AUCTION = 1
    UIEVENT_TYPE = { SPECIALTY_RATIO_BETWEEN_INFO = "ratio", AUCTION_ITEM_SEARCHED = "auction" }
    UIParent = { SetEventHandler = function(_, event, handler) events[event] = handler end }
    X2Locale = { GetLocale = function() return locale end }
    X2Auction = {
        SearchAuctionArticle = function(_, page, minLevel, maxLevel, grade, category, exact, name, minPrice, maxPrice)
            assert(page == 1 and minLevel == 0 and maxLevel == 999 and grade == 1)
            assert(category == 0 and exact == false and minPrice == "0" and maxPrice == "0")
            searches[#searches + 1] = name
            if searchFails then error("模擬搜尋失敗") end
        end,
        GetSearchedItemCount = function() return 1 end,
        GetSearchedItemInfo = function() return auctionResult end,
    }
    local stateChanges = 0
    CT = {
        Chat = function(message) messages[#messages + 1] = message end,
        MainWindow = {
            Refresh = Noop,
            OnAuctionStateChanged = function() stateChanges = stateChanges + 1 end,
        },
    }
    dofile("locale.lua")
    dofile("data/zones.lua")
    dofile("data/specialties.lua")
    dofile("trade.lua")
    dofile("auction.lua")
    local auction = CT.Auction
    local a = { name = locale == "zh_cn" and "细须柔顺剂" or "Small Root Pigment", itemType = 19448 }
    local b = { name = locale == "zh_cn" and "胚芽皮革油" or "Small Seed Oil" }

    auction.SearchMaterial(a)
    assert(opens == 1 and #searches == 0, "先開啟拍賣場，延後搜尋")
    auction.Tick(299)
    assert(#searches == 0)
    auction.Tick(1)
    assert(#searches == 1 and searches[1] == a.name)
    auction.Tick(10000)
    assert(#searches == 1, "搜尋完成後不應重複送出")

    auction.SearchMaterial(a)
    auction.Tick(200)
    auction.SearchMaterial(b)
    auction.Tick(299)
    assert(#searches == 1)
    auction.Tick(1)
    assert(#searches == 2 and searches[2] == b.name, "連續選取只搜尋最後一個材料")
    for _, material in ipairs({
        { name = CT.Text("BLUE_SALT_BOND") },
        { name = "Gilda Star", itemType = 23633 },
    }) do
        auction.SearchMaterial(material)
    end
    auction.Tick(300)
    assert(opens == 3 and #searches == 2, "不可交易材料不應開啟或搜尋拍賣場")

    auction.SearchMaterial(a)
    auction.Cancel()
    auction.Tick(300)
    assert(#searches == 2, "取消時應一併清除待送出的搜尋")
    auction.SearchMaterial(b)
    auction.StartForPacks({ { isSpecialty = true, materials = { a, b } } })
    assert(#searches == 3 and searches[3] == a.name and auction.IsRunning())
    auction.Tick(300)
    assert(#searches == 3, "開始批次查價時應取消待送出的手動搜尋")
    auctionResult = { name = a.name, bidPrice = 123 }
    events.auction()
    auction.Tick(900)
    assert(#searches == 4 and searches[4] == b.name)

    local previousStateChanges = stateChanges
    auction.SearchMaterial(a)
    assert(not auction.IsRunning() and stateChanges == previousStateChanges + 1,
        "手動搜尋應停止批次查價並更新按鈕狀態")
    auctionResult = { name = b.name, bidPrice = 999 }
    events.auction()
    assert(auction.PriceOf(a) == 123 and auction.PriceOf(b) == 0,
        "停止後應保留已取得的成本並忽略未完成的查價")
    auction.Tick(300)
    assert(#searches == 5 and searches[5] == a.name)
    events.auction()
    assert(auction.PriceOf(a) == 123 and auction.PriceOf(b) == 0,
        "手動搜尋結果不應誤記為批次材料成本")
    auction.Tick(10000)
    assert(#searches == 5, "批次查價不應在手動搜尋後繼續送出")

    openFails = true
    auction.SearchMaterial(a)
    auction.Tick(300)
    assert(#searches == 5 and #messages == 1)
    assert(messages[1] == CT.Text("AUCTION_OPEN_FAILED") and messages[1] ~= "AUCTION_OPEN_FAILED")
    openFails, searchFails = false, true
    auction.SearchMaterial(a)
    auction.Tick(300)
    assert(#searches == 6 and #messages == 2)
    assert(messages[2] == CT.Text("AUCTION_SEARCH_FAILED") and messages[2] ~= "AUCTION_SEARCH_FAILED")
    auction.Tick(10000)
    assert(#searches == 6 and #messages == 2, "失敗後不應重複搜尋或提示")
    searchFails = false
    auction.SearchMaterial(b)
    auction.Tick(300)
    assert(#searches == 7 and searches[7] == b.name, "失敗後應能再次搜尋")
    print("PASS: " .. locale .. " 材料拍賣延遲、連續選取、批次查價互斥與失敗處理")
end

Run("zh_cn")
Run("en_us")
