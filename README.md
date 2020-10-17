# UT99-Tools
PowerShell tools for troubleshooting Unreal Tournament 99 Servers.


# Cmdlets

## Get-UtMasterServerEndpointList

Retrieves a list of IP Endpoints from master servers. It's useful for testing if your UT99 game server is successfully announcing its presence to a master server. 
        
When a UT Game server is started it might say:

    UdpServerUplink: Master Server is master.mplayer.com:27900
    UdpServerUplink: Port 7779 successfully bound.
However, this just means that it was able to resolve the DNS host name to an IP address and bind to port 7779 on the system.
It does not mean the game server successfully announced its presence to that master server. 

Another problem is the UT99 Game client, will only show a list of servers in the browser that it managed to ping, 
so, you will not know if the problem is between the client and the game server, or the game server and the master server.

This cmdlet allows you to test two things
1. The master server address and port number are responding to connections.
2. The list of IP addresses is retrievable and your game server's IP address is on that list.


# Contributing
Please feel free to help out by either creating issues, or solving them. 
