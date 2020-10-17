try {
    $endpoint = [IPEndpoint]::new([ipaddress]::Broadcast, 7778)
    $udpClient = New-Object System.Net.Sockets.UdpClient
    $udpClient.EnableBroadcast = $true
    $udpClient.Connect($endpoint)
    $encoding = [System.Text.AsciiEncoding]::new()

    [Byte[]] $sendQueryBytes = $encoding.GetBytes("REPORTQUERY");
    $udpClient.Send($sendQueryBytes, $sendQueryBytes.Length);


    #IPEndPoint object will allow us to read datagrams sent from any source.
    $RemoteIpEndPoint = [IPEndPoint]::new([IPAddress]::Any, 0);
    [Byte[]] $receiveBytes = $udpClient.Receive([ref]$RemoteIpEndPoint);
    [string] $returnData = $encoding.GetString($receiveBytes);
    $returnData
} finally {
    $udpClient.Close()
}





