#Script will auto enter the parameter - e.g. 1544761260000
Param([Parameter(Mandatory=$true)][Long]$Timestamp=$null)

### TARGET FILES ###
$ScriptFolder = "...\Dynatrace\CAS\wwwroot\taskexports\Data_Extract\"
$ScriptName = "Data_Extract$Timestamp.txt"
$ScriptPath = "$ScriptFolder\$ScriptName"
# Only exporting data from the <CLUSTER> cluster
$SoftwareService = "<SOFTWARE SERVICE>"

### HTTPS REQUEST PREREQUISITES ###
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$URLHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$URLHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$URLHeaders.Add("accept", "application/json; charset=utf-8")
$URLHeaders.Add("Content-Type", "application/json; charset=utf-8")

### DYNATRACE MANAGED CONFIG ###
$PROD_DTM_SERVER = "https://dynatrace/e/<ENV_ID>/api/v1/entity/infrastructure/custom/"
$PROD_API_TOKEN = "PROD_TOKEN"
#$DEV_DTM_SERVER = "https://dynatrace-dev/e/<ENV_ID>/api/v1/entity/infrastructure/custom"
#$DEV_API_TOKEN = "DEV_TOKEN>"
$SAAS_DTM_SERVER = "https://<DYNATRACE_URL>/api/v1/entity/infrastructure/custom/"
$SAAS_API_TOKEN = "<TOKEN>"
$CustomEntityName = "<ENTITY NAME>"

$DTM_ENDPOINT = "$($SAAS_DTM_SERVER)/$($CustomEntityName)?Api-Token=$SAAS_API_TOKEN"

### CSV FORMATTING ###
$raw = Get-Content $ScriptPath
# Keep the header - contains dimension and value names
$raw = ($raw -replace "# Zone", "Zone")
# Clean the garbage - start with # - to import as csv
$csv = $raw | Where { $_ -notmatch "^#" } | ConvertFROM-Csv

### CREATE AND SEND PAYLOAD ###
# Make sure you have first 'Put' the custom metrics into timeseries API
# https://www.dynatrace.com/support/help/dynatrace-api/environment/timeseries-api/manage-custom-metrics-via-api/#anchor_put_metric
$jsdate = $Timestamp
foreach ($row in $csv)
{
    $payload = @{
        "groupId"="DCRUM Zone";
        "type"="DCRUM";
        "series" = @(
          @{
            "timeseriesId"="custom:DCRUMTotalBytes";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone" = "$($row.'Zone')"
            };
            "dataPoints" = @( 
                ,@($jsdate, [float]$row.'Total bytes (B)')
            ) 
          },
          @{
           "timeseriesId"="custom:DCRUMClientBandwidthUsage";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Client bandwidth usage (bps)')
            )
          },
          @{
           "timeseriesId"="custom:DCRUMServerBandwidthUsage";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Server bandwidth usage (bps)')
            )
          },
          @{
           "timeseriesId"="custom:DCRUMTotalBandwidthUsage";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Total bandwidth usage (bps)')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMNetworkPerf";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone" = "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Network performance (%)')
            )
          },      
          @{
            "timeseriesId"="custom:DCRUMEndtoEndRTT";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone" = "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'End-to-end RTT (ms)')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMTwoWayLossRate";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone" = "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Two-way loss rate(%)')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMUniqueUsers";
            "dimensions"= @{
              "Software_Service"= "$SoftwareService";
              "Zone" = "$($row.'Zone')"
            
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Unique users')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMApplicationPerformance";
            "dimensions"= @{
              "Software_Service" = "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Application performance (%)')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMOperationTime";
            "dimensions"= @{
              "Software_Service" = "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Operation time (ms)')
            )
          },
          @{
            "timeseriesId"="custom:DCRUMAvailabilityTotal";
            "dimensions"= @{
              "Software_Service" = "$SoftwareService";
              "Zone"= "$($row.'Zone')"
            };
            "dataPoints" = @(
                ,@($jsdate, [float]$row.'Availability (total) (%)')
            )
          }
        )
    }

    $JSONPayload = ($payload | ConvertTo-Json -Depth 8 | Out-string)
    write-Host $JSONPayload

    Invoke-RestMethod -Uri $DTM_ENDPOINT -Method 'POST' -Headers $URLHeaders -Body $JSONPayload
}