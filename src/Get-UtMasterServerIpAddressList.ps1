function Get-UtMasterServerEndpointList {
    <#
    .SYNOPSIS
        Retrieves Endpoints from Master Servers.
    .DESCRIPTION
        Retrieves a list of IP Endpoints from master servers. It's useful for testing if your UT99 game server is successfully announcing its presense to a master server. 
        
        When a UT Game server is started it might say:
        UdpServerUplink: Master Server is master.mplayer.com:27900
        UdpServerUplink: Port 7779 successfully bound.
        However, this just means that it was able to a) resolve the dns host name to an ip address and b) bind to the port 7779 on the system. 
        It does not mean the game server successfully announced its presense to that master server. 

        Another problem is the UT99 Game client, will only show a list of servers in the browser that it managed to ping, 
        so, you will not know if the problem is between the client and the game server, or the game server and the master server.

        This cmdlet allows you to test two things
        1. The master server address and port number are responding to connections.
        2. The list of IP addresses is retrievable and your game server's ip address is on that list.

    .EXAMPLE
        PS C:\> Get-UtMasterServerEndpointList -Address utmaster.epicgames.com 
        AddressFamily Address          Port
        ------------- -------          ----
        InterNetwork 147.135.23.65    7978
        InterNetwork 216.155.140.138  7778
        InterNetwork 213.230.216.2    8889
        InterNetwork 85.14.229.240    7778
        InterNetwork 5.9.21.239       8076


        Providing only the required parameters will return the list of endpoints

    .EXAMPLE
        PS C:\> Get-UtMasterServerEndpointList -Address master.333networks.com
        
        The challenge received from the server was \basic\\secure\HZVXFR\final\.  
        This cmdlet can't handle any key other than the one used by epic servers.

        In this example, the address for a master server was given where the challenge was outside of the capabilities of this cmdlet (for now).
        However, it did respond with a challenge which is shown in the host output, which means the server is there and responding to connections.
        This is a way you can test master servers to see if they are responding to requests. 
    .EXAMPLE
        PS C:\> Get-UtMasterServerEndpointList -Address unreal.epicgames.com | where Address -eq '181.43.152.180'
        
        AddressFamily Address        Port
        ------------- -------        ----
        InterNetwork 181.43.152.180 8201
        InterNetwork 181.43.152.180 8301
        InterNetwork 181.43.152.180 8401
        InterNetwork 181.43.152.180 7778
        InterNetwork 181.43.152.180 8305

        In this example, the endpoints are filtered to only show Endpoints where the ip address equals '181.43.152.180'.
    .INPUTS
        string
    .OUTPUTS
        object[] or System.Net.IPEndpoint
    .NOTES
        Known issues:
            - The cmdlet will only download IPEndpoints from servers that use the challenge '\basic\\secure\wookie' 
    .LINK
        https://github.com/RIKIKU/UT99-Tools
    #>
    
    [cmdletbinding()]
    param( 
        # IP address or hostname of the master server
        [Parameter(Mandatory = $true)]
        [string]
        $Address,
        # Port number to connect to the server on. Default 28900
        [Parameter(Mandatory = $false)]
        [int]
        $Port = 28900 
    )
    begin {
        #region helpy helpertons
        function streamDataWaiter {
            <#
        .SYNOPSIS
            Waits for the stream.DataAvailable to be true or to timeout before moving on.  
        #>
            [CmdletBinding()]
            param (
                #The stream to check for data.
                [Parameter(Mandatory = $true)]
                [System.Net.Sockets.NetworkStream]
                $stream,
                #Effectively a timeout. Each loop waits 200 ms between each check.
                [Parameter(Mandatory = $false)]
                [int]
                $LoopLimit = 2000 
            )

            $loop = 0
            while ($stream.DataAvailable -eq $false -and $loop -lt $LoopLimit) {
                $loop++
                Write-Verbose "Waiting for Server Response"
                Start-Sleep -m 200
            }
            if ($loop -ge $LoopLimit) {
                Write-Error "Connection Timed-out waiting for response from server." -ErrorAction Stop
            }
        }

        #endregion

    }
    process {
        try {
       
            try {
                Write-Verbose "Attempting connection to host"
                $socket = New-Object System.Net.Sockets.TcpClient( $Address, $port )
            } catch {
                Write-Error -Message $_.Exception.Message -Exception $_.Exception -ErrorAction Stop
            }


            $stream = $socket.GetStream( )
            $writer = New-Object System.IO.StreamWriter( $stream )
            $buffer = New-Object System.Byte[] 1024
            $encoding = New-Object System.Text.AsciiEncoding
            $IpString = [System.Text.StringBuilder]::new()

            streamDataWaiter -stream $stream
     
            while ($stream.DataAvailable) {
                $read = $stream.Read( $buffer, 0, 1024 )
                $SecurityChallenge = $encoding.GetString( $buffer, 0, $read )
                Write-Verbose "Security Challenge $SecurityChallenge"
            }

            #One time I had to wait for the stream to become writable. 
            while ($stream.CanWrite -eq $false) {
                Write-Verbose "waiting for stream to be writeable"
                Start-Sleep -m 10
            }
        
            <#
            If the security challenge is 'wookie', we know the validation of that challenge we have to send back is '2/TYFMRc'
            Implementing gsmsalg is how you would get the correct validation for different keys.
            #>
            if ($SecurityChallenge -eq '\basic\\secure\wookie') {
            
                Write-Verbose "Sending request for ip address list"
                $writer.WriteLine("\gamename\ut\location\0\validate\2/TYFMRc\final\\list\gamename\ut\")
                $writer.Flush( )
                #sometimes, this loop gets stuck here. I need to fix this. maybe with a timeout? 
                #Adding the sleep above seemed to fix the issue, but it's not a good implementation.
                streamDataWaiter -stream $stream

                while ( $stream.DataAvailable ) {
                    Write-Verbose "Receiving List of Endpoints"
                    $read = $stream.Read( $buffer, 0, 1024 )
                    $IpString.Append($encoding.GetString( $buffer, 0, $read )) | Out-Null
            
                    while ($stream.DataAvailable -eq $false) {
                        if ($IpString.tostring() -match 'final') { break }
                        Start-Sleep -m 10
                    }
                }
                Write-Verbose "Processing Ip Address List."
                $IpString = $IpString.ToString().Split('\final')[0]
                $IpString.Split('\ip\', [StringSplitOptions]::RemoveEmptyEntries).ForEach( { [IPEndpoint]::Parse($_) | Write-Output })
            } else {
                Write-Host "The challenge received from the server was $SecurityChallenge`nThis cmdlet can't handle any challenge other than the one used by epic servers."
            }
            
        
    
        } finally {
            if ( $writer ) {	$writer.Close( )	}
            if ( $stream ) {	$stream.Close( )	}
        } 
    }
    end {}
}