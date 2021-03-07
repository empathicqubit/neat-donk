# Donkey Kong Country 2 NEAT

An AI based on SethBling's MarI/O to play Donkey Kong Country 2 with lsnes.

## Requirements

* lsnes with **Lua 5.2** (do not try to build with 5.3, it does not work!)
* A Donkey Kong Country 2 1.1 US ROM (matching hash b79c2bb86f6fc76e1fc61c62fc16d51c664c381e58bc2933be643bbc4d8b610c)

## Instructions

1. Start lsnes
2. Go to `Configure -> Settings -> Advanced` and change `LUA -> Maximum memory use` to `1024MB`
3. Load the DKC2 ROM: `File -> Load -> ROM...`
4. Load the script: `Tools -> Run Lua script...`
5. You may also want to turn off sound since it may get annoying. `Configure -> Sounds enabled`
6. Look at config.lua for some settings you can change. Not all have been tested, but you should be able to change the number on the `_M.Filename =` line to get a different state file from the `_M.State` list.

## Keys
1: Stop/start

4: Play the best run

6: Save the pool file

8: Load the pool file

9: Restart

## Notes
* Only tested on Pirate Panic
* The pool files are gzipped json

## Credits

* [Donkey Hacks](http://donkeyhacks.zouri.jp/html/En-Us/dkc2/index.html)
* [SethBling's Mar I/O](https://github.com/mam91/neat-genetic-mario)
* [Basic tilemap info from p4plus2/DKC2-disassembly](https://github.com/p4plus2/DKC2-disassembly)
* [dkjson](http://dkolf.de/src/dkjson-lua.fsl/home)
* [LibDeflate](https://github.com/SafeteeWoW/LibDeflate)
