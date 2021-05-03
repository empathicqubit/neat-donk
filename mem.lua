local _M = {
    addr = {
        kremcoins = 0x7e08cc,
        tileCollisionMathPointer = 0x7e17b2,
        spriteBase = 0x7e0de2,
        verticalPointer = 0xc414,
        tiledataPointer = 0x7e0098,
        haveBoth = 0x7e08c2,
        ---Height in game units for vertical levels, width for horizontal
        areaLength = 0x7e17b4,
        ---This is always the traditional width no matter the level type
        areaWidth = 0x7e0afc,
        ---This is always the traditional height no matter the level type
        areaHeight = 0x7e0afe,
        cameraX = 0x7e17ba,
        cameraY = 0x7e17c0,
        cameraX2 = 0x7e0ad7,
        cameraY2 = 0x7e0adb,
        leadChar = 0x7e08a4,
        partyX = 0x7e0a2a,
        partyY = 0x7e0a2c,
        solidLessThan = 0x7e00a0,
        kongLetters = 0x7e0902,
        mathLives = 0x7e08be,
        displayLives = 0x7e0c0,
        mainAreaNumber = 0x7e08a8,
        currentAreaNumber = 0x7e08c8,
    },

    flag = {
        sprite = {
            dying = 0x1000,
        }
    },

    size = {
        tile = 32,
        enemy = 64,
        sprite = 94,
    },

    offset = {
        sprite = {
            control = 0x00,
            x = 0x06,
            y = 0x0a,
            jumpHeight = 0x0e,
            style = 0x12,
            velocityX = 0x20,
            velocityY = 0x24,
        }
    }
}

return _M
