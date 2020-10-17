
function Invoke-UtServerQuery {
    <#
    .SYNOPSIS
        Send a query to a UT Game Server.
    .DESCRIPTION
        Send a query message to a Game Server's query port (game port + 1). 
        This will retrieve the type of information that's usually visible in the game "Find Internet Games window" and more.
    .EXAMPLE
        PS C:\> Find-UtLanServers | Invoke-UtServerQuery

        hostaddress  : 192.168.0.6
        hostport     : 7777
        worldlog     : false
        maptitle     : Frigate
        maxplayers   : 16
        gamemode     : openplaying
        gametype     : Assault
        mapname      : AS-Frigate
        hostname     : Testing UT Server In Docker
        wantworldlog : false
        minnetver    : 432
        queryid      : 5.1
        numplayers   : 1
        gamever      : 451

        In this example, Find-UtLanServers  locates a server on the LAN and Invoke-UtServerQuery performs the info query on it.. 

    .EXAMPLE
        PS C:\> Get-UtMasterServerEndpointList -Address utmaster.epicgames.com | where Address -eq '181.43.152.180'  | Invoke-UtServerQuery -QueryType rules | select hostname,mapname,numplayers
        
        hostname                           mapname    numplayers
        --------                           -------    ----------
        [Ragnarok] Heimdall - DM 1v1 - ip2 CTF-Lucius 0
        [Ragnarok] Odin - [Pug] ip3        CTF-Lucius 0
        [Ragnarok] Thor - [Pug] ip4        CTF-Lucius 0
        [Ragnarok] Tyr - CTF/DM Publico -… CTF-Novem… 0
        [Ragnarok] Loki - [Pug] ip5 OldCo… CTF-Incin… 0

        In this example, we query the master server for a list of game servers, then filter the list to only IP addresses that match '181.43.152.180' and query only those servers. 
        Then we filter the output to only show hostname, mapname and numplayers.
    .INPUTS
        String, Int
    .OUTPUTS
        PSCustomObject
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        #Address of the UT server to Query.    
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Address,
        # The Game Server's query port (ServerPort + 1)
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Port')]
        [int]
        $QueryPort,
        # Query type can be one of the following values: info, rules, players, 'status', 'echo', 'level_property', 'player_property'
        [Parameter(Mandatory = $false)]
        [ValidateSet(
            'info',
            'rules',
            'players',
            'status',
            'echo',
            'level_property',
            'player_property',
            IgnoreCase = $false
        )]
        [string]
        $QueryType = 'info'
    )
    begin {
    }
    process {
        try {
            
            $respondentEndpoint = [IPEndpoint]::new([ipaddress]::Parse($Address), $QueryPort)
            $UtServerUtpClient = [System.Net.Sockets.UdpClient]::new($respondentEndpoint.Port)

            $UtServerUtpClient.Client.SendTimeout = 2000
            $UtServerUtpClient.Client.ReceiveTimeout = 5000
            $UtServerUtpClient.Connect($respondentEndpoint)

            $encoding = [System.Text.AsciiEncoding]::new()

            $query = '\{0}\' -f $QueryType
            [Byte[]] $sendInfoBytes = $encoding.GetBytes($query);
            $UtServerUtpClient.Send($sendInfoBytes, $sendInfoBytes.Length) | Out-Null

            [Byte[]] $receiveBytes = $UtServerUtpClient.Receive([ref]$respondentEndpoint)
            $returnData = $encoding.GetString($receiveBytes) 

        } catch {
            if ($_.Exception.InnerException.ErrorCode -eq 10060) {
                Write-Verbose "Host $($respondentEndpoint.ToString()) Didn't respond."
            }
        } finally {
            if ($UtServerUtpClient) {
                $UtServerUtpClient.Close()
                $UtServerUtpClient.Dispose()
            }
        }

        if ($returnData) {
            <#  
            The response from the server is something like:
            \hostname\UT Server In Docker\hostport\7777\maptitle\HiSpeed...
            It's essentially a key value pair in string format, so we split it into separate objects and order them as a hash table. 
            The hash is converted into a pscustomobject for that powershell feeling. 
            #>  
            Write-Verbose "Server Response:  $returnData "

            #remove leading \ or \\ depending.
            
            $returnData = $returnData.Substring(1, $returnData.Length - 1)
            if ($returnData.Substring(0, 2) -eq '\\') {
                $returnData = $returnData.Substring(2, $returnData.Length - 2)
            }
            $splitPath = $returnData.Split('\')
            $hash = @{}
            try {
                for ($i = 0; $i -lt $splitPath.Count; $i++) {
                    $hash[$splitPath[$i]] = $splitPath[$i + 1]
                    $i++
                }
                #final isn't used for anything.
                $hash.Remove('final')
                #Adding host address to output to make it more useful. 
                $hash['hostaddress'] = $respondentEndpoint.Address
                [PSCustomObject]$hash | Write-Output
            } catch {
                Write-Error " There was a problem processing the response from the server."
            }
        }
    }
    end {

    }
}
