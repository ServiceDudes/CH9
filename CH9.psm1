Function Get-CH9EventItem{
	<#
		.SYNOPSIS
			This functions helps you load items from Chennel 9 events.
	
		.DESCRIPTION
			Use this function to load session events from Channel 9, like TechEd, Build, Ignite etc.
	
		.PARAMETER  Event
			The Event you want to query for sessions.
	
		.PARAMETER  Year
			The Year of the Event.
	
		.PARAMETER  Region
			Where the Event took place.
		
		.PARAMETER  Category
			What the session was about.

		.PARAMETER  Speaker
			Who is making the presentation.
		
		.EXAMPLE
			Get-CH9EventItem -Event Build -Year 2015 -Region NorthAmerica
		
		.EXAMPLE
			Get-CH9EventItem -Event Ingite -Year 2015 -Region NorthAmerica -Speaker 'Snover'
	
	#>

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('Build','TechEd','Ignite','AzureCon','CloudBurst','TechDays')]
        [string[]]$EventName, 

        [Parameter(Mandatory=$true, Position=1)]
        [ValidatePattern("^\d{4}$")]
        [int[]]$Year,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateSet('NorthAmerica','Europe','Australia','Sweden')]
        [String]$Region,

        [Parameter(Mandatory=$false, Position=3)]
        [string]$Category,

        [Parameter(Mandatory=$false, Position=4, HelpMessage="Name of the speaker, like Snover")]
        [string]$Speaker,

        [Parameter(Mandatory=$false, Position=5)]
        [string]$Title,

        [Parameter(Mandatory=$false, Position=6)]
        [int]$Pages = 3

    )
    BEGIN{
    }
    
    PROCESS{
        
        $EventItems = @()
        
        ForEach ($Event in $EventName){
        
            Write-Verbose "Loading event API endpoint for $Event"

            #Check Year:
            ForEach ($y in $Year){
            
                If($Event -eq "teched"){
                    $EventSessionsURL              = "http://s.ch9.ms/Events/$Event/$Region/$y/RSS/mp4high"
                    $EventSessionsPresentationsURL = "http://s.ch9.ms/Events/$Event/$Region/$y/RSS/Slides"
                }
                ElseIf($Event -eq "AzureCon"){
                    $EventSessionsURL = "https://channel9.msdn.com/Events/Microsoft-Azure/AzureCon-$y/RSS/mp4high"
                    $EventSessionsPresentationsURL  = "https://channel9.msdn.com/Events/Microsoft-Azure/AzureCon-$y/RSS/Slides"
                }
                ElseIf($Event -eq "CloudBurst"){
                    $EventSessionsURL = "https://channel9.msdn.com/Events/Cloud-Burst/CloudBurst-$y/RSS/mp4high"
                    $EventSessionsPresentationsURL  = "https://channel9.msdn.com/Events/Cloud-Burst/CloudBurst-$y/RSS/Slides"
                }
                ElseIf($Event -eq "TechDays"){
                    $EventSessionsURL = "https://channel9.msdn.com/Events/TechDays-$Region/TechDays-$Region-$y/RSS/mp4high"
                    $EventSessionsPresentationsURL  = "https://channel9.msdn.com/Events/TechDays-$Region/TechDays-$Region-$y/RSS/Slides"
                }
                Else{
                    $EventSessionsURL              = "http://s.ch9.ms/Events/$Event/$y/RSS/mp4high"
                    $EventSessionsPresentationsURL = "http://s.ch9.ms/Events/$Event/$y/RSS/Slides"
                }

                Write-Verbose "API Endpoint set to: $EventSessionsURL"

                # Get all Event Sessions, presenations and videos:
                Try{
                    #We need to overloadload items to verify all event sessions:
                    $EventSessions = @()
                    $EventSessionsPresentations = @()
                    $i = 1
                    While($i -ne $Pages)
                    {
                       $EventSessions += Invoke-RestMethod $($EventSessionsURL + "?Page=$i") -ErrorAction SilentlyContinue
                       $EventSessionsPresentations += Invoke-RestMethod $($EventSessionsPresentationsURL + "?Page=$i") -ErrorAction SilentlyContinue
                       $i++
                    }

                    # Filter from all Sessions,if we need to.
                    $FilteredEventSessions      = @()
                    $Filter                     = $false
                    If($Category){$FilteredEventSessions += $EventSessions | Where-Object {$_.category -like "*$Category*"} ; Write-Verbose "Filtering on $Category"; $Filter=$true}
                    If($Speaker) {$FilteredEventSessions += $EventSessions | Where-Object {$_.creator  -like "*$Speaker*"}  ; Write-Verbose "Filtering on $Speaker" ; $Filter=$true}
                    If($Title)   {$FilteredEventSessions += $EventSessions | Where-Object {$_.title    -like "*$Title*"}    ; Write-Verbose "Filtering on $Title"   ; $Filter=$true}
    
                    Write-Verbose "Found number of filtred objects: $($FilteredEventSessions.Count)"
                    If($Filter){$EventSessions = $FilteredEventSessions}

                    # Create a custom Event object.
                    ForEach ($EventSession in $EventSessions){
                        
                        $EventId = $($EventSession.link.split("/") | Select-Object -Last 1).ToUpper()
                        
                        $VideoURLHigh = $EventSession.GetElementsByTagName('enclosure').url

                        $PresentationSlide = $EventSessionsPresentations | Where-Object {$_.link -eq $EventSession.link}
                        If($PresentationSlide){
                            If(($PresentationSlide.Count) -gt 1){$PresentationSlide = $PresentationSlide[0]}
                            $PresentationSlideURL = $PresentationSlide.GetElementsByTagName('enclosure').url}
                        Else{$PresentationSlideURL = ''}
                
                        $EventItem = [pscustomobject]@{ 'EventID'      = [string]$EventId;
                                                        'Title'        = [string]$EventSession.title;                                                       
                                                        'Summary'      = [string]$EventSession.summary;
                                                        'Speaker'      = [string]$EventSession.Creator;
                                                        'Category'     = [string]$EventSession.Category;
                                                        'Duration'     = [int]$($EventSession.Duration);
                                                        'URL'          = [string]$EventSession.link;
                                                        'VideoURLHigh' = [string]$($VideoURLHigh).ToString();
                                                        'SlideURL'     = [string]$PresentationSlideURL;
                                                        'Year'         = [string]$y;
                                                        'Event'        = [string]$Event
                                                        'Region'       = [string]$Region
                                                     }

                        $EventItem.PSObject.TypeNames.Insert(0,'CH9.EventItem')

                        If($EventItem.EventId -in $EventItems.EventId){
                           Write-Verbose "Event Item pressent: $EventId" 
                           Write-Verbose "$($EventItems.Count)"                   
                        }
                        Elseif ($EventItem -ne $null){
                           Write-Verbose "New Event: $EventId" 
                           $EventItems += $EventItem

                           Write-Output $EventItem
                        }
                    }
                }
                Catch{
                    Write-Verbose "Error in API call: $_.Exception.Message"
                }
            }
        }
    }     
 
 END{
    Write-Verbose "Exit count $($EventItems.Count)"
 }
    
}

Function Save-CH9EventItem {
<#
.SYNOPSIS
	This functions helps you dowbload items from Chennel 9 events.
	
.DESCRIPTION
	Use this function to download session events from Channel 9, like TechEd, Build, Ignite etc.
	
.PARAMETER  EventId
	The Event session event Id loaded from Get-CH9EventItem

.PARAMETER  Title
	The Event session title loaded from Get-CH9EventItem

.PARAMETER  VideoURLHigh
	The Event session video URL loaded from Get-CH9EventItem

.PARAMETER  SlideURL
	The Event session Presentation URL loaded from Get-CH9EventItem

.PARAMETER  Content
	Where to save you data, defaults to Desktop
	
.PARAMETER  StorePath
	Where to save you data, defaults to Desktop
		
.EXAMPLE
	Get-CH9EventItem -Event Ingite -Year 2015 -Speaker 'Snover' | Save-CH9EventItem

.EXAMPLE
	Get-CH9EventItem -Event Ingite -Year 2015 -Speaker 'Snover' | Save-CH9EventItem -StorePath C:\temp -Content Presentation
	
#>
[CmdletBinding()]
param (
	[ValidateNotNull()]
	[parameter(Position=0, 
               Mandatory=$true, 
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true)]
    [Alias('id')]
	[string[]]$EventId,

	[ValidateNotNull()]
    [parameter(Position=1, 
               Mandatory=$true, 
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true)]
	[string[]]$Title,

	[parameter(Position=2, 
               Mandatory=$false, 
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true)]
	[string[]]$VideoURLHigh,

	[parameter(Position=3, 
               Mandatory=$false, 
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true)]
	[string[]]$SlideURL,

    [Parameter(Position=4,
               Mandatory=$false,
               ValueFromPipeline = $false)]
    [ValidateSet('Presentation','Video','All')]
    [String]$Content = "All",

	[parameter(Position=5,
               Mandatory = $false,
               ValueFromPipeline = $false)]
	[string]$StorePath = [Environment]::GetFolderPath("MyVideos")
)

    BEGIN{
        If(Test-Path "$StorePath\CH9"){
            Write-Verbose "Folder CH9 present on store location"
        }Else{
            Write-Verbose "Create new save location"
            $Folder = New-Item -Path "$StorePath\CH9" -ItemType Directory
        }
    }
    PROCESS{

            #Rename the event with ID and Title, max 100 char...
            $Pattern = "[^a-zA-Z0-9\s]"
            $EventName = $("$EventId " + "$Title")
            $EventName = $EventName -replace $pattern, ""

            Write-Verbose "Event to save: $EventName"
            If (Test-Path "$StorePath\CH9\$EventName"){
                Write-Verbose "Folder $StorePath\CH9\$EventName is present in store location"
            }Else {
                Write-Verbose "Create new save location: $StorePath\CH9\$EventName"

                $Folder = "$StorePath\CH9\$EventName"
                If($Folder.Length -gt 200){
                    $Remaining = 200 - ($Folder.Length)
                    $EventName = $EventName.Substring(0,$Remaining-1)                   
                }

                $Folder = New-Item -Path "$StorePath\CH9\$EventName" -ItemType Directory
            }

            #Check for video file, else download it to folder...
            If (($VideoURLHigh) -and (($Content) -like "All") -or (($Content) -like "Video")){
                $Video = "$StorePath\CH9\$EventName\$EventId.mp4"

                If (Test-Path $Video){
                    Write-Verbose "$Video already downloaded!"
                }
                Else{
                    Write-Verbose "Start download for $EventId..."
                    Start-BitsTransfer -Source $VideoURLHigh -Destination $Video -DisplayName "$EventId.mp4" -ErrorAction SilentlyContinue
                }
            }

            #Check for presenation
            If (($SlideURL) -and (($Content) -like "All") -or (($Content) -like "Presentation")){
                $Presentation = "$StorePath\CH9\$EventName\$EventId.pptx"
                If (Test-Path $Presentation){
                    Write-Verbose "$Presentation already downloaded!"
                }
                Else{
                    Try{
                       Write-Verbose "Start download for $EventId..."
                       Start-BitsTransfer -Source $SlideURL -Destination $Presentation -DisplayName "$EventId.pptx" -ErrorAction SilentlyContinue
                    }
                    Catch{
                    
                    }
                }
            }    
    }
    END{}
}