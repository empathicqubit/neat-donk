local _M = {}

_M.Sprites = {}

-- Make sure this list is sorted before initialization.
_M.NeutralSprites = {
    krowEggFragments = 0x0020,
    barrelFragments = 0x0060,
    barrelFragments2 = 0x0064,

    -- Our heroes
    diddy = 0x00e4,
    dixie = 0x00e8,
    stars = 0x0100,

    -- Items that require too much interaction
    barrel = 0x01a4, -- Barrel
    cannonball = 0x01b0,
    chest = 0x01c0,
    smallCrate = 0x01bc,
    barrel2 = 0x011c,
    cannon = 0x013c,
    hook = 0x014c,
    tnt = 0x01b8,

    -- Inert
    goalPole = 0x0168,
    goalroulette = 0x016c,
    goalBase = 0x0160,
    goalBarrel = 0x0164,

    pow = 0x0238,
    explodingCrate = 0x023c,
    noAnimalsSign = 0x0258,
}

-- Make sure this list is sorted before initialization.
_M.GoodSprites = {
    -- Destinations
    areaExit = 0x0094,
    goalTarget = 0x00b0,

    bonusBarrel = 0x0120,
    hotAirBalloon = 0x0128,
    launchBarrel = 0x0140,
    animalCrate = 0x0148,
    invincibilityBarrel = 0x0150,
    midpoint = 0x0154,
    allCoins = 0x015c, -- Banana Coin/Kremkoin/DK Coin
    bananaBunch = 0x0170,
    kongLetter = 0x0174,
    upBalloon = 0x0178, -- xUP balloon

    -- Animals
    squitter = 0x0190,
    rattly = 0x0194,
    squawks = 0x0198,
    rambi = 0x019c,
    clapper = 0x0304,

    dkBarrelLabel = 0x01a8,

    krowEgg = 0x01b4,

    flitter = 0x0220,
    krocheadAllColors = 0x02d4,
}

-- Currently not used.
_M.BadSprites = {
    -- Baddies
    kannon = 0x006c,
    klobberAllColors = 0x01ac,
    kannonFodder = 0x01d0,
    krusha = 0x01d8,
    clickClack = 0x01dc,
    neek = 0x01e4,
    klomp = 0x01ec,
    klobberAwake = 0x01e8,
    klampon = 0x01f0,
    flotsam = 0x01f8,
    klinger = 0x0200,
    puftup = 0x0208,
    zingerAllColors = 0x0218,
    miniNecky = 0x0214,
    lockjaw = 0x020c,
    kaboing = 0x021c,
    krow = 0x0224, -- Boss
    krook = 0x025c,
}

_M.SpriteNames = {}

function _M.InitSpriteNames()
    for v,k in pairs(_M.GoodSprites) do
        _M.SpriteNames[k] = v
    end
    for v,k in pairs(_M.BadSprites) do
        _M.SpriteNames[k] = v
    end
    for v,k in pairs(_M.NeutralSprites) do
        _M.SpriteNames[k] = v
    end
end

function _M.InitSpriteList()
    for k,v in pairs(_M.GoodSprites) do
        _M.Sprites[v] = 1
    end
    for k,v in pairs(_M.BadSprites) do
        _M.Sprites[v] = -1
    end
    for k,v in pairs(_M.NeutralSprites) do
        _M.Sprites[v] = 0
    end
end

_M.extSprites = {}

-- Make sure this list is sorted before initialization.
_M.ExtNeutralSprites = {
}

_M.ExtGoodSprites = {
    banana01 = 0xe0, -- banana
    banana02 = 0xe1, -- banana
    banana03 = 0xe2, -- banana
    banana04 = 0xe3, -- banana
    banana05 = 0xe4, -- banana
    banana06 = 0xe5, -- banana
    banana07 = 0xe6, -- banana
    banana08 = 0xe7, -- banana
    banana09 = 0xe8, -- banana
    banana10 = 0xe9, -- banana
    banana11 = 0xea, -- banana
    banana12 = 0xeb, -- banana
    banana13 = 0xec, -- banana
    banana14 = 0xed, -- banana
    banana15 = 0xee, -- banana
}

-- Currently not used.
_M.ExtBadSprites = {
}

function _M.InitExtSpriteList()
    for k,v in pairs(_M.ExtGoodSprites) do
        _M.extSprites[v] = 1
    end
    for k,v in pairs(_M.ExtBadSprites) do
        _M.extSprites[v] = -1
    end
    for k,v in pairs(_M.ExtNeutralSprites) do
        _M.extSprites[v] = 0
    end
end

return _M
