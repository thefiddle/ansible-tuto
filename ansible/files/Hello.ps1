Write-Host "Hello! i'm running in directory "
Write-Host (Get-Item -Path ".\" -Verbose).FullName
for($i=0; $i -lt $args.length; $i++)
{
	"Arg $i : $($args[$i])"
}
