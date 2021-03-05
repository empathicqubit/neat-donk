local _M = {}

_M.Sprites = {}

-- Make sure this list is sorted before initialization.
_M.NeutralSprites = {
    0x0020, -- Krow egg fragments
    0x0064, -- Barrel fragments

    -- Our heroes
    0x00e4, -- Diddy
    0x00e8, -- Dixie

    -- Items that require too much interaction
    0x01a4, -- Barrel
    0x01b0, -- Cannonball (immobile)
    0x01c0, -- Chest
    0x01bc, -- Small crate
    0x011c, -- Barrel
    0x013c, -- Cannon
    0x014c, -- Hook
    0x01b8, -- TNT

    -- Inert
    0x0168, -- Goal pole
    0x016c, -- Goal roulette
    0x0160, -- Goal base
    0x0164, -- Goal barrel

    0x023c, -- Exploding crate
    0x0258, -- No Animals Sign
}

-- Make sure this list is sorted before initialization.
_M.GoodSprites = {
    -- Destinations
    0x0094, -- Area exit
    0x00b0, -- Goal target

    0x0120, -- Bonus barrel
    0x0128, -- Hot air balloon
    0x0140, -- Launch barrel
    0x0148, -- Animal crate
    0x0150, -- Invincibility barrel
    0x0154, -- Midpoint
    0x015c, -- Banana Coin/Kremkoin/DK Coin
    0x0170, -- Banana bunch
    0x0174, -- KONG letters
    0x0178, -- xUP balloon

    -- Animals
    0x0190, -- Squitter
    0x0194, -- Rattly
    0x0198, -- Squawks
    0x019c, -- Rambi
    0x0304, -- Clapper

    0x01b4, -- Krow's eggs

    0x0220, -- Flitter (used as unavoidable platforms in some levels)
    0x02d4, -- Krochead (red and green)
}

-- Currently not used.
_M.BadSprites = {
    -- Baddies
    0x006c, -- Kannon
    0x01ac, -- Klobber (yellow and green)
    0x01d0, -- Kannon's fodder (Ball/barrel)
    0x01d8, -- Krusha
    0x01dc, -- Click-Clack
    0x01e4, -- Neek
    0x01ec, -- Klomp
    0x01e8, -- Klobber (awake)
    0x01f0, -- Klampon
    0x01f8, -- Flotsam
    0x0200, -- Klinger
    0x0208, -- Puftup
    0x0218, -- Zinger (red and yellow)
    0x0214, -- Mini-Necky
    0x020c, -- Lockjaw
    0x021c, -- Kaboing
    0x0224, -- Krow (Boss)
    0x025c, -- Krook (very large)
}

function _M.InitSpriteList()
    local k = 1
    local j = 1
    for i=1, 256 do
        local isGood = (k <= #_M.GoodSprites) and (_M.GoodSprites[k] == i - 1)
        local isNeutral = (j <= #_M.NeutralSprites) and (_M.NeutralSprites[j] == i - 1)
        if isGood then
            k = k + 1
            _M.Sprites[#_M.Sprites + 1] = 1
        elseif isNeutral then
            j = j + 1
            _M.Sprites[#_M.Sprites + 1] = 0
        else
            _M.Sprites[#_M.Sprites + 1] = -1
        end
    end
end

_M.extSprites = {}

-- Make sure this list is sorted before initialization.
_M.ExtNeutralSprites = {
}

_M.ExtGoodSprites = {
    0xe0, -- banana
    0xe1, -- banana
    0xe2, -- banana
    0xe3, -- banana
    0xe4, -- banana
    0xe5, -- banana
    0xe6, -- banana
    0xe7, -- banana
    0xe8, -- banana
    0xe9, -- banana
    0xea, -- banana
    0xeb, -- banana
    0xec, -- banana
    0xed, -- banana
    0xee, -- banana
}

-- Currently not used.
_M.ExtBadSprites = {
}

function _M.InitExtSpriteList()
    local j = 1
    for i=1, 21 do
        local isExtNeutral = (j <= #_M.ExtNeutralSprites) and (_M.ExtNeutralSprites[j] == i - 1)
        local isExtGood = (j <= #_M.ExtGoodSprites)
        if isExtNeutral then
            j = j + 1
            _M.extSprites[#_M.extSprites + 1] = 0
        elseif isExtGood then
            j = j + 1
            _M.extSprites[#_M.extSprites + 1] = 1
        else
            _M.extSprites[#_M.extSprites + 1] = -1
        end
    end
end

return _M