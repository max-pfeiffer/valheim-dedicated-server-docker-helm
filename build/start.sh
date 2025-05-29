#!/bin/bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:SteamAppID=892970

./valheim_server.x86_64 -name "servername" -port 2456 -nographics -batchmode -world "worldname" -password "password" -public 1
