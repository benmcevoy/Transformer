# args
$sourceRootPath = "D:\Dev\git\Transformer\website" # args[0]
$outputRootPath = "D:\Dev\git\Transformer\build\output" # args[1]
$environments = Get-Content environments.debug.txt # args[2]
$files = Get-Content files.txt # args[2]

function Main
{
    # clean
    if(Test-Path $outputRootPath) { Remove-Item $outputRootPath -recurse }
    New-Item $outputRootPath -type directory

    # process
    foreach($environment in $environments) 
    {
        New-Item "$outputRootPath\$environment" -type directory

        foreach($file in $files){
            Transform $environment $file
        }
    }
}

function Transform ($environment, $file) 
{
    $ext = [System.IO.Path]::GetExtension($file)
    $source = "$sourceRootPath\$file"
    $transform = $source -replace [regex]::Escape($ext), ".$environment$ext"
    $output = "$outputRootPath\$environment\$file"
    
    EnsureDirectory($output)

    if(Test-Path $transform)
    {
        # do the transform
        Create-WebConfigTransform $source $transform $output
    } 
    else 
    {
        # no transform? - just copy the source file
        Copy-Item $source $output 
    }
}

function EnsureDirectory($path){
 # ensure destination folder exists
    $folder = [System.IO.Path]::GetDirectoryName($path)
    if(-not(Test-Path $folder)) { New-Item $folder -type directory }
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
    New-Item -Path ${WorkDir} -Type Directory
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
Main