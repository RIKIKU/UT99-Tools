function Find-UtLanServers {
    try {
        
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.EnableBroadcast = $true
        $udpClient.Client.ReceiveTimeout = 2000
        $udpClient.Client.SendTimeout = 2000
        $encoding = [System.Text.AsciiEncoding]::new()
    
        #fishing for servers on the network.
        [Byte[]] $sendQueryBytes = $encoding.GetBytes("REPORTQUERY");
        8777..8786 | ForEach-Object { $udpClient.Send($sendQueryBytes, $sendQueryBytes.Length, [IPEndPoint]::new([IPAddress]::Broadcast, $_)) | Out-Null }
        
        #new Testing
        <# [System.AsyncCallback]::new($recv)
        $udpClient.BeginReceive($recv, $state) #>
        while ($true) {
            $ServerEndpoint = [IPEndpoint]::new([ipaddress]::Any, 0)
            [Byte[]] $receiveBytes = $udpClient.Receive([ref]$ServerEndpoint)
            [string] $returnData = $encoding.GetString($receiveBytes);
    
            if ($returnData) {
                $output = [PSCustomObject]@{
                    GameType = $returnData.Split(' ')[0]
                    Port     = $returnData.Split(' ')[1]
                    Address  = $ServerEndpoint.Address
                }
                $output | Write-Output
            }
        }
    } catch {
        if ($_.Exception.InnerException.ErrorCode -eq 10060) {
            Write-Verbose "haven't heard anything for a while. Shutting the connection down. "
        }
    } finally {
        $udpClient.Close()
        
    }
}

function Get-UtLanServerInfo {
    [CmdletBinding()]
    param (
        #Address of the UT server to request info from.    
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Address,
        # Parameter help description
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int]
        $Port
    )
    begin {
        $encoding = [System.Text.AsciiEncoding]::new()
    }
    process {

        $respondentEndpoint = [IPEndpoint]::new([ipaddress]::Parse($Address), $Port)
    
        try {
            $UtServerUtpClient = [System.Net.Sockets.UdpClient]::new($respondentEndpoint.Port)

            $UtServerUtpClient.Connect($respondentEndpoint)

            [Byte[]] $sendInfoBytes = $encoding.GetBytes("\info\");
            $UtServerUtpClient.Send($sendInfoBytes, $sendInfoBytes.Length) | Out-Null

            [Byte[]] $receiveBytes = $UtServerUtpClient.Receive([ref]$respondentEndpoint)
            $returnData = $encoding.GetString($receiveBytes) 

        } finally {
            $UtServerUtpClient.Close()
        }

        <#
    The response from the server is something like:
    \hostname\UT Server In Docker\hostport\7777\maptitle\HiSpeed...
    It's essentially a key value pair in string format.
    So we split it into separate objects and order them as a hash table. 
    The hash is converted into a pscustomobject for that powershell feeling. 
    #>
        $splitPath = $returnData.Split('\', [StringSplitOptions]::RemoveEmptyEntries)
        $hash = @{}
        for ($i = 0; $i -lt $splitPath.Count; $i++) {
            $hash[$splitPath[$i]] = $splitPath[$i + 1]
            $i++
        }
        $hash.Remove('final')
        $hash['hostaddress'] = $respondentEndpoint.Address
        [PSCustomObject]$hash | Write-Output
    }
    end {}
}



Find-UtLanServers | Get-UtLanServerInfo






