#! /bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
xpra start --bind-tcp=127.0.0.1:5309 --html=on --start-child="lsnes --lua=$SCRIPT_DIR/neat-donk.lua" --exit-with-child=yes --start-new-commands=no
