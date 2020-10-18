
function Find-UtLanServers {
    <#
        .SYNOPSIS
            Find UT Servers on a Lan and write their response to the pipeline. 
        .DESCRIPTION
            Mimics the behavior of the UT client when a user selects the "Find LAN games option" by sending out broadcast packets to ports 8777-8786 and reading the responses it recieves.
        .EXAMPLE
            PS C:\> Find-UtLanServers
            
            GameType QueryPort Address
            -------- --------- -------
            ut       7778      192.168.0.6

            Running the Cmdlet will find all servers that are listening on the correct port range and output the above result.
        .INPUTS
            
        .OUTPUTS
            PsCustomObject
    #>
    try {
        
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.EnableBroadcast = $true
        $udpClient.Client.ReceiveTimeout = 2000
        $udpClient.Client.SendTimeout = 2000
        $encoding = [System.Text.AsciiEncoding]::new()
    
        #fishing for servers on the network.
        [Byte[]] $sendQueryBytes = $encoding.GetBytes("REPORTQUERY");
        8777..8786 | ForEach-Object { $udpClient.Send($sendQueryBytes, $sendQueryBytes.Length, [IPEndPoint]::new([IPAddress]::Broadcast, $_)) | Out-Null }
        
        while ($true) {
            $ServerEndpoint = [IPEndpoint]::new([ipaddress]::Any, 0)
            [Byte[]] $receiveBytes = $udpClient.Receive([ref]$ServerEndpoint)
            [string] $returnData = $encoding.GetString($receiveBytes);
    
            if ($returnData) {
                $output = [PSCustomObject]@{
                    GameType  = $returnData.Split(' ')[0]
                    QueryPort = $returnData.Split(' ')[1]
                    Address   = $ServerEndpoint.Address
                }
                $output | Write-Output
            }
        }
    } catch {
        if ($_.Exception.InnerException.ErrorCode -eq 10060) {
            Write-Verbose "Haven't heard anything for a while. Shutting the connection down. "
        }
    } finally {
        $udpClient.Close()
        $udpClient.Dispose()
        
    }
}