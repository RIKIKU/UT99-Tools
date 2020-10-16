function Get-UtMasterServerEndpointList {
    <#
    .SYNOPSIS
        Gets a list of Ip Addresses and port numbers from Master Servers.
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    
    [cmdletbinding()]
    param( 
        # IP address or hostname
        [Parameter(Mandatory = $true)]
        [string]
        $Address,
        # Port number to connec to the server on. Usually 28900
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
                $SecurityKeyResponse = $encoding.GetString( $buffer, 0, $read )
                Write-Verbose "Security Key $SecurityKeyResponse"
            }

            <# while ($stream.CanWrite -eq $false) {
            Write-Verbose "waiting for stream to be writeable"
            Start-Sleep -m 10
        } #>
        
            #If the security key is 'wookie', we know the validation of that key we have to send back is '2/TYFMRc'
            #Implementing gsmsalg is how you would get the correct validation for different keys, but I won't implement that here.
            if ($SecurityKeyResponse -eq '\basic\\secure\wookie') {
            
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
            }
            Write-Verbose "Processing Ip Address List."
            $IpString = $IpString.ToString().Split('\final')[0]
            $IpString.Split('\ip\', [StringSplitOptions]::RemoveEmptyEntries).ForEach( { [IPEndpoint]::Parse($_) | Write-Output })
        
    
        } finally {
            if ( $writer ) {	$writer.Close( )	}
            if ( $stream ) {	$stream.Close( )	}
        } 
    }
    end {}
}

<# Write-Host "Started Query Run At $(get-date)"
do {
    $results = Get-UtMasterServerEndpointList -Address utmaster.epicgames.com
    $ImHere = $results | where Address -EQ '121.200.8.51'
    Start-Sleep -Seconds 30 
} while ($ImHere) 

get-date #>


Get-UtMasterServerEndpointList -Address unreal.epicgames.com -Verbose # | where Address -EQ '121.200.8.51'