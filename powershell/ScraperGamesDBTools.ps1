#*****************************************************************************************************************************************
#This is the PowerShell Script For Analyzing Scraped data
#
#For Now I need it to Move ByGameName 0 Count json search results. 
#Becuase it seems (USA) at end of search make some matches come back with zero results. Want to make it possible to match on more Titles.
#
#gamesdb Links
#https://thegamesdb.net/
#https://api.thegamesdb.net/#/
#
#v2019-11-09
#*****************************************************************************************************************************************



#*****************************************************************************************************************************************
#TO USE: set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************
#Local Paths
$global:ByGameName_Dir = "E:\Downloads\thegamesdb\XXX\ByGameName";
$global:ZeroMatches_Dir = "E:\Downloads\thegamesdb\XXX\ZeroMatches";

$global:Path2GamesMappingXML = "E:\Downloads\thegamesdb\XXX\gamesDBMapping.xml";

# ****************************************************************************************************************************
# HANDLE ERROR
# ****************************************************************************************************************************
function HandleError([string] $ErrMsg)
{
    Write-Host -foregroundcolor red -backgroundcolor black $ErrMsg
    Exit #Stop Execution of the script
}



#*****************************************************************************************************************************************
#Iterate Game List Files json files
#Move those with 0 counts to ZeroMatches_Dir
#So we can try again with better search titles.
#*****************************************************************************************************************************************
function processJSONFiles()
{
    Write-Host -foregroundcolor green -backgroundcolor black "processJSONFiles() $global:ByGameName_Dir"


    $FilesArr = get-childitem -Recurse -Path $global:ByGameName_Dir -include *.json
    Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " Games List  jsons"


    #Iterate Each json file in $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName

        Write-Host -foregroundcolor cyan -backgroundcolor black $fileTitle

        if (!(Test-Path -LiteralPath $FullName))
            {
                HandleError("$FullName does not exist") #If this happens signal problem!
                exit
            }

        $json = $null
        $json = Get-Content -LiteralPath $FullName | ConvertFrom-Json
        if ($json -eq $null)
        {
            HandleError "Unable to open results json file $FullName as json"
        }

        if ($json.data.games.length -eq 0)
        {
            Move-Item $FullName -Destination $global:ZeroMatches_Dir
        }

    }#END OF iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



   Write-Host -foregroundcolor green -backgroundcolor black "Leaving gamesDBMapping"
}

#*****************************************************************************************************************************************
#Erase all Negative ID Nodes so we can try again to find matches
#*****************************************************************************************************************************************
function CleanUp_gamesDBMapping_xml()
{
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesMappingXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }

    [System.Xml.XmlElement] $gameListNode = $xw.DocumentElement;

    Foreach($gameNode in $xw.gameList.game)
    {
        [string] $idStr = $gameNode.id;
        [int] $idINT = [int]$idStr;
        if ($idINT -lt 0)
        {

           $gameListNode.RemoveChild($gameNode);
        }
    }#end of Foreach($gameNode in $xg.gameList.game)


    #Save Mapping XML with User Selections for Game ID's
    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
    $xw.Save($sw);
    $sw.Close();

return;
}

#*****************************************************************************************************************************************
#Main Execution Begins Here
#*****************************************************************************************************************************************
Clear-Host

#processJSONFiles


CleanUp_gamesDBMapping_xml
