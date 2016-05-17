# CH9
A PowerShell Module that downloads content from Channel 9

This Module is used for downloading sessions from events like Ignite, TechEd and Build.

To use the CmdLet just type:
Get-CH9EventItem -EventName Ignite -Year 2015 -Region NorthAmerica

Or filter it on speaker:
Get-CH9EventItem -EventName Build -Year 2015 -Region NorthAmerica -Speaker Snover

And to download just pipe over to save CmdLet:
Get-CH9EventItem -EventName Build -Year 2015 -Region NorthAmerica -Speaker Snover | Save-CH9EventItem
