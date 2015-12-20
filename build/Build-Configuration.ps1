$global:sourceRootPath = $args[0]
$global:outputRootPath = $args[1]
$environments = Get-Content $args[2]
$files = Get-Content $args[3]

function Main($environments, $files)
{
    # clean
    if(Test-Path $global:outputRootPath) { Remove-Item $global:outputRootPath -recurse | Out-Null }
    New-Item $global:outputRootPath -type directory | Out-Null

    # process
    foreach($environment in $environments) 
    {
        if([string]::IsNullOrWhiteSpace($environment)) { continue }
        if($environment.StartsWith("#")) { continue }

        New-Item "$global:outputRootPath\$environment" -type directory | Out-Null 

        foreach($file in $files)
        {
            if([string]::IsNullOrWhiteSpace($file)) { continue }
            if($file.StartsWith("#")) { continue }

            Transform $environment $file
        }
    }
}

function Transform($environment, $file) 
{
    Write-Host "Starting Transform for:" $environment $file -foregroundcolor "green"

    $ext = [System.IO.Path]::GetExtension($file)
    $source = "$global:sourceRootPath\$file"
    # we only ever had a use case for web.Shared.config
    # if $shared exists it will ALWAYS be applied  for every $environment 
    # even if there is no specific environment transform
    $shared = $source -replace [regex]::Escape($ext), ".Shared$ext"
    $transform = $source -replace [regex]::Escape($ext), ".$environment$ext"
    $output = "$global:outputRootPath\$environment\$file"

    EnsureDirectory($output)

    if(Test-Path $shared)
    {
        # do the $shared transform to an intermediate
        $working = "$global:outputRootPath\_delete.me"
        Create-WebConfigTransform $source $shared $working
        $source = $working
    }

    if(Test-Path $transform)
    {
        # do the $environment transform
        Create-WebConfigTransform $source $transform $output
        return
    } 
    
    # no $environment transform? - just copy the source file
    Copy-Item $source $output 
}

function EnsureDirectory($path)
{
    # ensure destination folder exists
    $folder = [System.IO.Path]::GetDirectoryName($path)
    if(-not(Test-Path $folder)) { New-Item $folder -type directory | Out-Null }
}

# copied from https://gist.github.com/mpicker0/5680072
function Create-WebConfigTransform($SourceFile, $TransformFile, $OutputFile) 
{
    # set up output filenames
    $WorkDir = Join-Path ${env:temp} "work-${PID}"
    $SourceWork = Join-Path $WorkDir (Split-Path $SourceFile -Leaf)
    $TransformWork = Join-Path $WorkDir (Split-Path $TransformFile -Leaf)
    $OutputWork = Join-Path $WorkDir (Split-Path $OutputFile -Leaf)

    # create a working directory and copy files into place
    New-Item -Path ${WorkDir} -Type Directory | Out-Null
    Copy-Item $SourceFile $WorkDir 
    Copy-Item $TransformFile $WorkDir

    # TODO: need to make the path to \Microsoft.Web.Publishing.Tasks.dll configurable or discoverable
    # write the project build file
    $BuildXml = @"
    <Project ToolsVersion="4.0" DefaultTargets="TransformWebConfig" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
      <UsingTask TaskName="TransformXml"
                 AssemblyFile="D:\Dev\git\Transformer\build\bin\Microsoft.Web.Publishing.Tasks.dll"/>
      <Target Name="TransformWebConfig">
        <TransformXml Source="${SourceWork}"
                      Transform="${TransformWork}"
                      Destination="${OutputWork}"
                      StackTrace="true" />
      </Target>
    </Project>
"@
    $BuildXmlWork = Join-Path $WorkDir "build.xml"
    $BuildXml | Out-File $BuildXmlWork
    
    # call msbuild
    & .\bin\MSBuild.exe $BuildXmlWork

    # copy the output to the desired location
    Copy-Item $OutputWork $OutputFile

    # clean up
    Remove-Item $WorkDir -Recurse -Force
}

# start
Main $environments $files