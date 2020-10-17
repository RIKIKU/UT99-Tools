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
        
    }
}