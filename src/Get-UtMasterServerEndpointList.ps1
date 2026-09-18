
function Get-UtMasterServerEndpointList {
    <#
        .SYNOPSIS
            Retrieves Endpoints from Master Servers.
        .DESCRIPTION
            Retrieves a list of IP Endpoints from master servers. It's useful for testing if your UT99 game server is successfully announcing its presense to a master server. 
            
            When a UT Game server is started it might say:
            UdpServerUplink: Master Server is master.mplayer.com:27900
            UdpServerUplink: Port 7779 successfully bound.
            However, this just means that it was able to a) resolve the dns host name to an ip address and b) bind to port 7779 on the system. 
            It does not mean the game server successfully announced its presense to that master server. 

            Another problem is the UT99 Game client, will only show a list of servers in the browser that it managed to ping,
            so, you will not know if the problem is between the client and the game server, or the game server and the master server.

            This cmdlet allows you to test two things
            1. The master server address and port number are responding to connections.
            2. The list of IP Endpoints is retrievable and your game server's IP Endpoint is among them.

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

            AddressFamily Address          Port
            ------------- -------          ----
            InterNetwork 147.135.23.65    7978
            InterNetwork 216.155.140.138  7778

            The cmdlet solves the server's secure challenge with the GameSpy algorithm (gsmsalg),
            so any master server that speaks the GameSpy 'secure' protocol for Unreal Tournament
            (gamename 'ut') will return its endpoint list.
        .EXAMPLE
            PS C:\> Get-UtMasterServerEndpointList -Address master.oldunreal.com -GameName ut -GameKey Z5Nfb0

            Supplying an explicit -GameName and -GameKey lets you query master servers for other
            GameSpy titles. The defaults ('ut' / 'Z5Nfb0') target Unreal Tournament, so they can
            be omitted for UT master servers.
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
            The master server's secure challenge is solved at runtime using the GameSpy master
            server algorithm (gsmsalg, enctype 0) keyed with the game key, so servers that issue
            different challenges are supported. Only the plain-text enctype 0 handshake used by
            Unreal Tournament master servers is implemented.
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
        $Port = 28900,
        # GameSpy game name announced in the list request. Default 'ut' (Unreal Tournament).
        [Parameter(Mandatory = $false)]
        [string]
        $GameName = 'ut',
        # GameSpy game key used to solve the master server's secure challenge. Default is the Unreal Tournament ('ut') key.
        [Parameter(Mandatory = $false)]
        [string]
        $GameKey = 'Z5Nfb0'
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

        function computeGsSecureResponse {
            <#
                .SYNOPSIS
                    Solves a GameSpy 'secure' challenge (gsmsalg, enctype 0) using the game key.
            #>
            [CmdletBinding()]
            param (
                # The challenge string sent by the master server (the value following '\secure\').
                [Parameter(Mandatory = $true)]
                [string]
                $Challenge,
                # The GameSpy game key used to validate the challenge.
                [Parameter(Mandatory = $true)]
                [string]
                $GameKey
            )

            # Maps a 6-bit value to a GameSpy base64-style output character (returns its ASCII code).
            function gsvalfunc([int]$reg) {
                if ($reg -lt 26) { return ($reg + 65) }
                if ($reg -lt 52) { return ($reg + 71) }
                if ($reg -lt 62) { return ($reg - 4) }
                if ($reg -eq 62) { return 43 }
                if ($reg -eq 63) { return 47 }
                return 0
            }

            $encoder = [System.Text.Encoding]::ASCII
            $src = $encoder.GetBytes($Challenge)
            $key = $encoder.GetBytes($GameKey)

            # Key-scheduling: build the initial permutation from the game key.
            $enctmp = New-Object 'int[]' 256
            for ($i = 0; $i -lt 256; $i++) { $enctmp[$i] = $i }
            $a = 0
            for ($i = 0; $i -lt 256; $i++) {
                $a = ($a + $enctmp[$i] + $key[$i % $key.Length]) -band 0xff
                $swap = $enctmp[$a]
                $enctmp[$a] = $enctmp[$i]
                $enctmp[$i] = $swap
            }

            # Encrypt the challenge, then zero-pad the buffer to a multiple of three bytes.
            $tmp = New-Object 'int[]' 66
            $a = 0
            $b = 0
            for ($i = 0; $i -lt $src.Length; $i++) {
                $a = ($a + $src[$i] + 1) -band 0xff
                $x = $enctmp[$a]
                $b = ($b + $x) -band 0xff
                $y = $enctmp[$b]
                $enctmp[$b] = $x
                $enctmp[$a] = $y
                $tmp[$i] = $src[$i] -bxor $enctmp[($x + $y) -band 0xff]
            }
            for ($size = $i; ($size % 3) -ne 0; $size++) {
                $tmp[$size] = 0
            }

            # Emit the response as GameSpy base64 (4 output chars per 3 input bytes).
            $sb = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt $size; $i += 3) {
                $x = $tmp[$i]
                $y = $tmp[$i + 1]
                $z = $tmp[$i + 2]
                [void]$sb.Append([char](gsvalfunc ($x -shr 2)))
                [void]$sb.Append([char](gsvalfunc ((($x -band 3) -shl 4) -bor ($y -shr 4))))
                [void]$sb.Append([char](gsvalfunc ((($y -band 15) -shl 2) -bor ($z -shr 6))))
                [void]$sb.Append([char](gsvalfunc ($z -band 63)))
            }
            $sb.ToString()
        }

        #endregion

    }
    process {
        try {
       
            try {
                Write-Verbose "Attempting connection to host"
                $tcpClient = New-Object System.Net.Sockets.TcpClient( $Address, $port )
                $tcpClient.Client.ReceiveTimeout = 5000
                $tcpClient.Client.SendTimeout = 5000
            } catch {
                Write-Error -Message $_.Exception.Message -Exception $_.Exception -ErrorAction Stop
            }


            $stream = $tcpClient.GetStream( )
            $writer = New-Object System.IO.StreamWriter( $stream )
            $buffer = New-Object System.Byte[] $tcpClient.ReceiveBufferSize
            $encoding = New-Object System.Text.AsciiEncoding
            $IpString = [System.Text.StringBuilder]::new()

            #streamDataWaiter -stream $stream
     
            $read = $stream.Read( $buffer, 0, $tcpClient.ReceiveBufferSize )
            $SecurityChallenge = $encoding.GetString( $buffer, 0, $read )
            Write-Verbose "Security Challenge $SecurityChallenge"

            <#
            The master server opens with '\basic\\secure\<challenge>'. The <challenge> is solved
            with the GameSpy master server algorithm (gsmsalg, enctype 0) keyed with the game key,
            producing the '\validate\' token the server expects. See computeGsSecureResponse.
            #>
            $challengeMatch = [regex]::Match($SecurityChallenge, '\\secure\\([^\\]+)')
            if (-not $challengeMatch.Success) {
                Write-Error "Unexpected handshake from server. Expected a '\secure\' challenge but received: $SecurityChallenge" -ErrorAction Stop
            }
            $challengeValue = $challengeMatch.Groups[1].Value
            Write-Verbose "Parsed secure challenge '$challengeValue'"

            $validate = computeGsSecureResponse -Challenge $challengeValue -GameKey $GameKey
            Write-Verbose "Computed validate response '$validate'"

            Write-Verbose "Sending request for ip address list"
            $writer.WriteLine("\gamename\$GameName\location\0\validate\$validate\final\\list\gamename\$GameName\")
            $writer.Flush( )
            #sometimes, this loop gets stuck here. I need to fix this. maybe with a timeout? 
            #Adding the sleep above seemed to fix the issue, but it's not a good implementation.

            do {
                Write-Verbose "Receiving List of Endpoints"
                $read = $stream.Read( $buffer, 0, $tcpClient.ReceiveBufferSize )
                $IpString.Append($encoding.GetString( $buffer, 0, $read )) | Out-Null
        
                while ($stream.DataAvailable -eq $false) {
                    if ($IpString.tostring() -match 'final') { break }
                    Write-Verbose "waiting for data"
                    Start-Sleep -m 20
                }
            }while ( $stream.DataAvailable ) 
            Write-Verbose "Processing Ip Address List."
            $IpString = $IpString.ToString().Split('\final')[0]
            $IpString.Split('\ip\', [StringSplitOptions]::RemoveEmptyEntries).ForEach( { [IPEndpoint]::Parse($_) | Write-Output })
        } finally {
            if ( $writer ) {	
                $writer.Close( )	
                $writer.Dispose()
            }
            if ( $stream ) {	
                $stream.Close( )
                $stream.Dispose()
            }
        } 
    }
    end {}
}