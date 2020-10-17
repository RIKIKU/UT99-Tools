
function Invoke-UtServerQuery {
    <#
    .SYNOPSIS
        Send a query to a UT Game Server.
    .DESCRIPTION
        Send a query message to a Game Server's query port (game port + 1).
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
        # Query type can be one of the following values: info, rules, players
        [Parameter(Mandatory = $false)]
        [ValidateSet('query', 'info', 'rules', 'players', 'status', 'echo', 'level_property', 'player_property')]
        [string]
        $QueryType = 'info'
    )
    begin {
        $encoding = [System.Text.AsciiEncoding]::new()
    }
    process {

        $respondentEndpoint = [IPEndpoint]::new([ipaddress]::Parse($Address), $QueryPort)
    
        try {
            $UtServerUtpClient = [System.Net.Sockets.UdpClient]::new($respondentEndpoint.Port)
            $UtServerUtpClient.Client.SendTimeout = 2000
            $UtServerUtpClient.Client.ReceiveTimeout = 2000
            $UtServerUtpClient.Connect($respondentEndpoint)

            [Byte[]] $sendInfoBytes = $encoding.GetBytes("\$QueryType\");
            $UtServerUtpClient.Send($sendInfoBytes, $sendInfoBytes.Length) | Out-Null

            [Byte[]] $receiveBytes = $UtServerUtpClient.Receive([ref]$respondentEndpoint)
            $returnData = $encoding.GetString($receiveBytes) 

        } catch {
            if ($_.Exception.InnerException.ErrorCode -eq 10060) {
                Write-Verbose "Host $($respondentEndpoint.ToString()) Didn't respond."
            }
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
        #remove leading \
        $returnData = $returnData.Substring(1, $returnData.Length - 1)
        $splitPath = $returnData.Split('\')
        $hash = @{}
        for ($i = 0; $i -lt $splitPath.Count; $i++) {
            $hash[$splitPath[$i]] = $splitPath[$i + 1]
            $i++
        }
        #final isn't used for anything.
        $hash.Remove('final')
        #Adding host address to output to make it more useful. 
        $hash['hostaddress'] = $respondentEndpoint.Address
        [PSCustomObject]$hash | Write-Output
    }
    end {}
}