# Donkey Kong Country 2 NEAT

An AI based on SethBling's MarI/O to play Donkey Kong Country 2 with lsnes.

See [YouTube](https://www.youtube.com/watch?v=-_UyUbObLeE) for an example run.

## Requirements

* lsnes with **Lua 5.2** (do not try to build with 5.3, it does not work!)
* socat for Linux, or a fairly recent version of Windows that has PowerShell
* A Donkey Kong Country 2 1.1 US ROM (matching hash b79c2bb86f6fc76e1fc61c62fc16d51c664c381e58bc2933be643bbc4d8b610c)

### Windows

You will want to install the rrtest-1613424691 version of lsnes. Older versions were crashing for me. The easiest way to do this is to use Chocolatey:

```powershell
# Make sure you use an Administrator shell!

# Skip this command if you have Chocolatey already.
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install lsnes
choco install --version 2.0.24-rrtest-1613424691 lsnes
```

## Instructions

1. Start lsnes
2. Go to `Configure -> Settings -> Advanced` and change `LUA -> Maximum memory use` to `1024MB`
3. Load the DKC2 ROM if you aren't using threads: `File -> Load -> ROM...`
4. Load the `neat-donk.lua` script: `Tools -> Run Lua script...`

## Config

Look at config.lua for some settings you can change. Not all have been tested.

* `_M.Filename`: Change the number to a different one from the `_M.State` list
to load a different file.
* `_M.NeatConfig.Threads`: Change this to 1 to prevent multiple instances of 
lsnes from getting launched at once, or increase it to run more instances.
If you use more than 1 thread, you may also want to launch `lsnes` using xpra
to manage the windows, with the [xpra-run.sh](xpra-run.sh) script.

## Keys
1: Stop/start

4: Play the best run

6: Save the pool file

8: Load the pool file

9: Restart

## Other Tools

### Status Overlay

The status overlay is located at [tools/status-overlay.lua](tools/status-overlay.lua).
It will help you see the tile and sprite calculations by marking the tiles with
their offsets on the screen, giving a crosshair with tile measurements every
32 pixels, and listing information about the sprites. You can use the 1 and 2
keys above the letter keys to page through them. Sprites labeled in green are
considered "good", red is "bad", normal color is neutral. Solid red means that
it's the active sprite in the info viewer.

<img src="https://github.com/empathicqubit/neat-donk/blob/master/doc/donkutil.png?raw=true" />

### BSNES Launcher

Located at [tools/bsnes-launcher.lua](tools/bsnes-launcher.lua), this script
gives you an easy way to launch bsnes-plus with breakpoints preset. Run it in
lsnes and it will display a message to the Lua console and stderr on how to use it.

## Notes
* Only tested on Pirate Panic
* The pool files are gzipped Serpent data

## Credits

* [Donkey Hacks](http://donkeyhacks.zouri.jp/html/En-Us/dkc2/index.html)
* [SethBling's Mar I/O](https://github.com/mam91/neat-genetic-mario)
* [Basic tilemap info from p4plus2/DKC2-disassembly](https://github.com/p4plus2/DKC2-disassembly)
* [Serpent](https://github.com/pkulchenko/serpent)
* [LibDeflate](https://github.com/SafeteeWoW/LibDeflate)
* [Billiam's Promise library](https://github.com/Billiam/promise.lua)
* [https://github.com/psmay/windows-named-pipe-utils](https://github.com/psmay/windows-named-pipe-utils)

## TODO

- [x] Incur penalty for non-hazardous enemy collisions to encourage neutralizing Klobber
- [ ] Award for picking up items
- [ ] Make enemies neutral when held? (Klobber, Click-Clack, etc.)
- [ ] Multiple nets to handle different contexts s/a clicking map items
