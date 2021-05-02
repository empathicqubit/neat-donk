#! /bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
#ARGS=("--lua=$SCRIPT_DIR/neat-donk.lua")
ARGS=()
PORT=5309
xpra start --bind-tcp=127.0.0.1:$PORT --html=on \
    --start-child="/etc/alternatives/x-terminal-emulator -e 'lsnes ${ARGS[*]}'" \
    --exit-with-child=yes --start-new-commands=no
while ! nc -z localhost $PORT ; do
    sleep 0.1
done
xdg-open http://127.0.0.1:$PORT
