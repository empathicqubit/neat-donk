PARTY_X = 0x7e0a2a
TILE_SIZE = 32

print(memory.readword(PARTY_X))

function on_post_rewind()
    print("Async?")
    print(memory.readword(PARTY_X))
end

function movement(addr, val)
    if memory.readword(addr) > TILE_SIZE * 20 then
        local rew = movie.to_rewind("pool/PiratePanic.lsmv")
        movie.unsafe_rewind(rew)
        print("Sync?")
        print(memory.readword(PARTY_X))
    end
end

memory2.WRAM:registerwrite(0x0a2a, movement)
