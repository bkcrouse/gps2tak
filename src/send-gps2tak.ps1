[cmdletbinding()]
param(
	[ValidateRange(-90,90)]
	[double]
	$StartLat = ([math]::round((get-random -Minimum 25.00 -Maximum 48.00),3)),
  
	[ValidateRange(-180,180)]
	[double]
	$StartLon = ([math]::round((get-random -Minimum -124.00 -Maximum -90.00),3)),

	[ValidateRange(-90,90)]
	[int]
	$LatBoundaryNorth = 48.00,
  
	[ValidateRange(-90,90)]
	[int]
	$LatBoundarySouth = 0.00,

	[ValidateRange(1,60)]
	[int]
	$Rate = 1,

	[ValidateRange(1,120)]
	[int]
	$Duration = 10,

	[switch]
	$Forever,

	[ValidateNotNullOrEmpty()]
	[string]
	$IPAddress
)

function Send-Udp
{
      Param ([string] $EndPoint, 
      [int] $Port, 
      [string] $Message)

      $IP = [System.Net.Dns]::GetHostAddresses($EndPoint) 
      $Address = [System.Net.IPAddress]::Parse($IP) 
      $EndPoints = New-Object System.Net.IPEndPoint($Address, $Port) 
      $Socket = New-Object System.Net.Sockets.UDPClient 
      $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message) 
      $SendMessage = $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints) 
      $Socket.Close() 
} 

function Get-NMEAChecksum ($plaintext)
{
    $plaintext.ToCharArray() | foreach-object -process {
        $checksum = $checksum -bxor [char]([byte][char] $_)
    }
    return [System.BitConverter]::ToString($checksum)
}

# convert lat to NMEA format
[int] $degrees = ($startLat -split '\.')[0]
[int] $minutes = (([int]($startLat -split '\.')[1]) * [int] 60) / 1000

# convert lon to NMEA format
[int] $degreesLon = ($StartLon -split '\.')[0]
[int] $minutesLon = (([int]($startLon -split '\.')[1]) * [int] 60) / 1000
$nmeaLon = "{0:d2}{1:d2}" -f $degreesLon, $minutesLon

$latDirection = 'N'
$next = 0
$step = 1
$trackAngle = 000.0
$newLat =  "{0:d2}{1:00.000}" -f $degrees, $minutes
Write-Verbose -Message "StartLat: $newLat" 


$startTime = get-date
#"yyyy-MM-ddTHH:mm:ss.ffZ"
$nmeaDateStamp = $startTime.ToUniversalTime().ToString("ddMMyy")
$nmeaTimeStamp = $startTime.ToUniversalTime().ToString("HHmmss")
$stopTime = $startTime.AddMinutes($Duration)
while( ((get-date) -lt $stopTime) -or $Forever ) {

	$nmeaString = 'GPRMC,' + $nmeaTimeStamp + ',A,' + $newLat + ',' + $latDirection + ',' + $nmeaLon +  ',E,060.0,' + $trackAngle + ',' + $nmeaDateStamp + ',003.1,W,'
	$data = '$' + $nmeaString + '*' + (Get-NMEACheckSum -plaintext $nmeaString)
	Send-UDP -Endpoint $IPAddress -Port 4349 -Message $data
	Start-Sleep -seconds $Rate

	if ( ($minutes + $step) -gt 59) {
		$minutes = 0
		$degrees += 1
	} elseif ( ($minutes + $step ) -lt 0 ) {
		$minutes = 59
		$degrees -= 1
	}

	if ( $degrees -ge $LatBoundaryNorth ) {
		$step = -1
		$trackAngle = 180.0
	} elseif( $degrees -lt $LatBoundarySouth) {
		$step = 1
		$trackAngle = 000.0
	}
	
	[int] $minutes = [math]::Floor($minutes + $step)
	$newLat =  "{0:d2}{1:00.000}" -f $degrees, $minutes
	write-verbose -message "Lat: $newlat, Lon: $nmeaLon"

}

