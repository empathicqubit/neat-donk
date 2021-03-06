# Donkey Kong Country 2 NEAT

An AI based on SethBling's MarI/O to play Donkey Kong Country 2 with lsnes.

## Requirements

* lsnes with **Lua 5.2** (do not try to build with 5.3, it does not work!)
* A Donkey Kong Country 2 ROM

## Instructions

1. Start lsnes
2. Go to `Configure -> Settings -> Advanced` and change `LUA -> Maximum memory use` to `1024MB`
3. Load the DKC2 ROM: `File -> Load -> ROM...`
4. Load the script: `Tools -> Run Lua script...`
5. You may also want to turn off sound since it may get annoying. `Configure -> Sounds enabled`

## Keys
1: Stop/start
4: Play the best run
6: Save the pool file
8: Load the pool file
9: Restart

## Notes
Only tested on Pirate Panic

## Credits

A lot of basic info came from [Donkey Hacks](http://donkeyhacks.zouri.jp/html/En-Us/dkc2/index.html), the NEAT A/I comes from [SethBling's Mar I/O](https://github.com/mam91/neat-genetic-mario), and basic information about the tilemap came from [p4plus2/DKC2-disassembly](https://github.com/p4plus2/DKC2-disassembly)
