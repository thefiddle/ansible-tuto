param (
	[string]$lang = "en-US"
)
Write-Host 'Changing lang for '	$env:UserName ' user : ' $lang
Import-Module International
# Set regional format (date/time etc.) s - this applies to all user
Set-Culture $lang
# Set the language list for the user
Set-WinUserLanguageList -LanguageList $lang -Force



#################
#$lang_obj = New-WinUserLanguageList $lang
#$lang_obj[0].Handwriting = $True
#Write-Host $lang_obj[0].InputMethodTips
#Set-WinDefaultInputMethodOverride -InputTip "$lang_obj[0].InputMethodTips"

