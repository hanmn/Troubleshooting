<#
.SYNOPSIS
    powershell script to to enumerate directory summarizing in tree view directories over a given size

.DESCRIPTION
    To download and execute with arguments:
    (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/directory-treesize.ps1","$pwd\directory-treesize.ps1");
    .\directory-treesize.ps1 d:\ -showPercent -detail -minSizeGB 0 -logFile $pwd\dts.log

    To enable script execution, you may need to Set-ExecutionPolicy Bypass -Force
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    
.NOTES
    File Name  : directory-treesize.ps1
    Author     : jagilber
    Version    : 180901 original
    History    : 

.EXAMPLE
    .\directory-treesize.ps1
    enumerate current working directory

.PARAMETER depth
    number of directory levels to display

.PARAMETER detail
    display additional file / directory detail
    output: path, total size of files in path, files in current directory / sub directories, directories in current directory / sub directories 
    example: g:\ size:184.209 GB files:5/98053 dirs:10/19387

.PARAMETER directory
    directory to enumerate

.PARAMETER logFile
    log output to log file

.PARAMETER minSizeGB
    minimum size of directory / file to display in GB

.PARAMETER noColor
    output in default foreground color only

.PARAMETER noTree
    output complete directory and file paths

.PARAMETER quiet
    do not display output

.PARAMETER showFiles
    output file information

.PARAMETER showPercent
    show percent graph

.PARAMETER uncompressed
    for windows file length is used instead of size on disk. this will show higher disk used but does *not* use pinvoke to kernel32
    uncompressed switch makes script pwsh compatible and is enabled by default when path contains '/'
    tested on ubuntu 18.04

.LINK
    https://raw.githubusercontent.com/jagilber/powershellScripts/master/directory-treesize.ps1
#>

[cmdletbinding()]
param(
    [string]$directory = (get-location).path,
    [float]$minSizeGB = .01,
    [int]$depth = 99,
    [switch]$detail,
    [switch]$noColor,
    [switch]$notree,
    [switch]$showFiles,
    [string]$logFile,
    [switch]$quiet,
    [switch]$showPercent,
    [switch]$uncompressed
)

$timer = get-date
$error.Clear()
$ErrorActionPreference = "silentlycontinue"
$drive = Get-PSDrive -Name $directory[0]
$writeDebug = $DebugPreference -ine "silentlycontinue"
$script:logStream = $null
$script:directories = @()
$script:directorySizes = @()
$script:foundtreeIndex = 0
$script:progressTimer = get-date
$pathSeparator = [io.path]::DirectorySeparatorChar
$isWin32 = $psversiontable.psversion -lt [version]"6.0.0" -or $global:IsWindows

function main()
{
    log-info "$(get-date) starting"
    log-info "$($directory) drive total: $((($drive.free + $drive.used) / 1GB).ToString(`"F3`")) GB used: $(($drive.used / 1GB).ToString(`"F3`")) GB free: $(($drive.free / 1GB).ToString(`"F3`")) GB"
    log-info "enumerating $($directory) sub directories, please wait..." -ForegroundColor Yellow

    $uncompressed = !$isWin32
    [dotNet]::Start($directory, $minSizeGB, $depth, [bool]$showFiles, [bool]$uncompressed)
    $script:directories = [dotnet]::_directories
    $script:directorySizes = @(([dotnet]::_directories).totalsizeGB)
    $totalFiles = (($script:directories).filesCount | Measure-Object -Sum).Sum
    $totalFilesSize = $script:directories[0].totalsizeGB
    log-info "displaying $($directory) sub directories over -minSizeGB $($minSizeGB): files: $($totalFiles) directories: $($script:directories.Count)"

    $sortedBySize = $script:directorySizes -ge $minSizeGB | Sort-Object
        
    if ($sortedBySize.Count -lt 1)
    {
        log-info "no directories found! exiting" -foregroundColor Yellow
        exit
    }

    $categorySize = [int]([math]::Floor([math]::max(1, $sortedBySize.Count) / 6))
    $redmin = $sortedBySize[($categorySize * 6) - 1]
    $darkredmin = $sortedBySize[($categorySize * 5) - 1]
    $yellowmin = $sortedBySize[($categorySize * 4) - 1]
    $darkyellowmin = $sortedBySize[($categorySize * 3) - 1]
    $greenmin = $sortedBySize[($categorySize * 2) - 1]
    $darkgreenmin = $sortedBySize[($categorySize) - 1]
    $previousDir = $directory.ToLower()
    [int]$i = 0

    for ($directorySizesIndex = 0; $directorySizesIndex -lt $script:directorySizes.Length; $directorySizesIndex++)
    {

        $previousDir = enumerate-directorySizes -directorySizesIndex $directorySizesIndex -previousDir $previousDir
    }

    log-info "$(get-date) finished. total time $((get-date) - $timer)"
}

function enumerate-directorySizes($directorySizesIndex, $previousDir)
{
    $currentIndex = $script:directories[$directorySizesIndex]
    $sortedDir = $currentIndex.directory
    log-info -debug -data "checking dir $($currentIndex.directory) previous dir $($previousDir) tree index $($directorySizesIndex)"
    [float]$totalSizeGB = $currentIndex.totalsizeGB
    log-info -debug -data "rollup size: $($sortedDir) $([float]$totalSizeGB)"

    switch ([float]$totalSizeGB)
    {
        {$_ -ge $redmin}
        {
            $foreground = "Red"; 
            break;
        }
        {$_ -gt $darkredmin}
        {
            $foreground = "DarkRed"; 
            break;
        }
        {$_ -gt $yellowmin}
        {
            $foreground = "Yellow"; 
            break;
        }
        {$_ -gt $darkyellowmin}
        {
            $foreground = "DarkYellow"; 
            break;
        }
        {$_ -gt $greenmin}
        {
            $foreground = "Green"; 
            break;
        }
        {$_ -gt $darkgreenmin}
        {
            $foreground = "DarkGreen"; 
        }

        default
        {
            $foreground = "Gray"; 
        }
    }

    if (!$notree)
    {
        while (!$sortedDir.Contains("$($previousDir)$($pathSeparator)"))
        {
            $previousDir = "$([io.path]::GetDirectoryName($previousDir))"
            log-info -debug -data "checking previous dir: $($previousDir)"
        }

        $percent = ""

        if ($showPercent)
        {
            if ($directorySizesIndex -eq 0)
            {
                # set root to files in root dir
                $percentSize = $currentIndex.sizeGB / $totalFilesSize
            }
            else 
            {
                $percentSize = $totalSizeGB / $totalFilesSize
            }

            $percent = "[$(('X' * ($percentSize * 10)).tostring().padright(10))]"
        }

        $output = $percent + $sortedDir.Replace("$($previousDir)$($pathSeparator)", "$(`" `" * $previousDir.Length)$($pathSeparator)")
    }
    else
    {
        $output = $sortedDir
    }

    if ($detail)
    {
        log-info ("$($output)" `
            + "`tsize:$(($totalSizeGB).ToString(`"F3`")) GB" `
            + " files:$($currentIndex.filesCount)/$($currentIndex.totalFilesCount)" `
            + " dirs:$($currentIndex.directoriesCount)/$($currentIndex.totalDirectoriesCount)") -ForegroundColor $foreground
    }
    else
    {
        log-info "$($output) `t$(($totalSizeGB).ToString(`"F3`")) GB" -ForegroundColor $foreground
    }

    if ($showFiles)
    {
        foreach ($file in ($currentIndex.files).getenumerator())
        {
            log-info ("$(' '*($output.length))$([int64]::Parse($file.value).tostring("N0").padleft(15))`t$($file.key)") -foregroundColor cyan
        }
    }

    return $sortedDir
}

function log-info($data, [switch]$debug, $foregroundColor = "White")
{
    if ($debug -and !$writeDebug)
    {
        return
    }

    if ($debug)
    {
        $foregroundColor = "Yellow"
    }

    if($noColor)
    {
        $foregroundColor = "White"
    }

    if (!$quiet)
    {
        write-host $data -ForegroundColor $foregroundColor
    }

    if($InformationPreference -ieq "continue")
    {
        Write-Information $data
    }

    if ($logFile)
    {
        if ($script:logStream -eq $null)
        {
            $script:logStream = new-object System.IO.StreamWriter ($logFile, $true)
        }

        $script:logStream.WriteLine($data)
    }
}


$code = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

public class dotNet
{
    [DllImport("kernel32.dll")]
    private static extern uint GetCompressedFileSizeW([In, MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
        [Out, MarshalAs(UnmanagedType.U4)] out uint lpFileSizeHigh);

    [DllImport("kernel32.dll", SetLastError = true, PreserveSig = true)]
    private static extern int GetDiskFreeSpaceW([In, MarshalAs(UnmanagedType.LPWStr)] string lpRootPathName,
       out uint lpSectorsPerCluster, out uint lpBytesPerSector, out uint lpNumberOfFreeClusters,
       out uint lpTotalNumberOfClusters);

    public static uint _clusterSize;
    public static int _depth;
    public static List<directoryInfo> _directories;
    public static float _minSizeGB;
    public static bool _showFiles;
    public static List<Task> _tasks;
    public static DateTime _timer;
    public static bool _uncompressed;
    public static string _pathSeparator = @"\";

    public static void Main() { }
    public static void Start(string path, float minSizeGB = 0.01f, int depth = 99, bool showFiles = false, bool uncompressed = false)
    {
        _directories = new List<directoryInfo>();
        _timer = DateTime.Now;
        _showFiles = showFiles;
        _tasks = new List<Task>();
        _uncompressed = uncompressed;
        _minSizeGB = minSizeGB;

        if(path.Contains("/"))
        {
            _pathSeparator = "/";
        }

        _depth = depth + path.Split(_pathSeparator.ToCharArray()).Count();

        if (!_uncompressed)
        {
            _clusterSize = GetClusterSize(path);
        }

        // add 'root' path
        directoryInfo rootPath = new directoryInfo() { directory = path.TrimEnd(_pathSeparator.ToCharArray()) };
        _directories.Add(rootPath);
        _tasks.Add(Task.Run(() => { AddFiles(rootPath); }));

        Console.WriteLine("getting directories");
        AddDirectories(path, _directories);
        Console.WriteLine("waiting for task completion");

        while (_tasks.Where(x => !x.IsCompleted).Count() > 0)
        {
            _tasks.RemoveAll(x => x.IsCompleted);
            Thread.Sleep(100);
        }

        Console.WriteLine(string.Format("total files: {0} total directories: {1}", _directories.Sum(x => x.filesCount), _directories.Count));
        Console.WriteLine("sorting directories");
        _directories.Sort();
        Console.WriteLine("rolling up directory sizes");
        TotalDirectories(_directories);
        Console.WriteLine("filtering directory sizes");
        FilterDirectories(_directories);

        // put trailing slash back in case 'root' path is root
        if (path.EndsWith(_pathSeparator))
        {
           _directories.ElementAt(0).directory = path;
        }

        Console.WriteLine(string.Format("Processing complete. minutes: {0:F3} filtered directories: {1}", (DateTime.Now - _timer).TotalMinutes, _directories.Count));
        return;
    }

    private static void AddDirectories(string path, List<directoryInfo> directories)
    {
        try
        {
            List<string> subDirectories = Directory.GetDirectories(path).ToList();

            foreach (string dir in subDirectories)
            {
                FileAttributes att = new DirectoryInfo(dir).Attributes;

                if ((att & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint)
                {
                    continue;
                }

                directoryInfo directory = new directoryInfo() { directory = dir };
                directories.Add(directory);
                _tasks.Add(Task.Run(() => { AddFiles(directory); }));
                AddDirectories(dir, directories);
            }
        }
        catch { }
    }

    private static void AddFiles(directoryInfo directoryInfo)
    {
        long sum = 0;

        try
        {
            DirectoryInfo dInfo = new DirectoryInfo(directoryInfo.directory);
            List<FileInfo> filesList = dInfo.GetFileSystemInfos().Where(x => (x is FileInfo)).Cast<FileInfo>().ToList();
            directoryInfo.directoriesCount = dInfo.GetDirectories().Count();

            if (_uncompressed)
            {
                sum = filesList.Sum(x => x.Length);
            }
            else
            {
                sum = GetSizeOnDisk(filesList);
            }

            if (sum > 0)
            {
                directoryInfo.sizeGB = (float)sum / (1024 * 1024 * 1024);
                directoryInfo.filesCount = filesList.Count;


                if (_showFiles)
                {
                    foreach (FileInfo file in filesList)
                    {
                        directoryInfo.files.Add(file.Name, file.Length);
                    }

                    directoryInfo.files = directoryInfo.files.OrderByDescending(v => v.Value).ToDictionary(x => x.Key, x => x.Value);
                }
            }
        }
        catch { }
    }

    private static void FilterDirectories(List<directoryInfo> directories)
    {
        _directories = directories.Where(x => x.totalSizeGB >= _minSizeGB & (x.directory.Split(_pathSeparator.ToCharArray()).Count() <= _depth)).ToList();
    }

    private static uint GetClusterSize(string fullName)
    {
        uint dummy;
        uint sectorsPerCluster;
        uint bytesPerSector;
        int result = GetDiskFreeSpaceW(fullName, out sectorsPerCluster, out bytesPerSector, out dummy, out dummy);

        if (result == 0)
        {
            return 0;
        }
        else
        {
            return sectorsPerCluster * bytesPerSector;
        }
    }

    public static long GetFileSizeOnDisk(FileInfo file)
    {
        // https://stackoverflow.com/questions/3750590/get-size-of-file-on-disk
        uint hosize;
        string name = file.FullName.StartsWith("\\\\") ? file.FullName : "\\\\?\\" + file.FullName;
        uint losize = GetCompressedFileSizeW(name, out hosize);
        long size;

        if (losize == 4294967295 && hosize == 0)
        {
            // 0 byte file
            return 0;
        }

        size = (long)hosize << 32 | losize;
        return ((size + _clusterSize - 1) / _clusterSize) * _clusterSize;
    }

    private static long GetSizeOnDisk(List<FileInfo> filesList)
    {
        long result = 0;

        foreach (FileInfo fileInfo in filesList)
        {
            result += GetFileSizeOnDisk(fileInfo);
        }

        return result;
    }

    private static void TotalDirectories(List<directoryInfo> dInfo)
    {
        directoryInfo[] dirEnumerator = dInfo.ToArray();
        int index = 0;
        int firstMatchIndex = 0;

        foreach (directoryInfo directory in dInfo)
        {

            if (directory.totalSizeGB > 0)
            {
                continue;
            }

            bool match = true;
            bool firstmatch = false;

            if (index == dInfo.Count)
            {
                index = 0;
            }

            string pattern = string.Format(@"{0}(\\|/|$)", Regex.Escape(directory.directory));

            while (match && index < dInfo.Count)
            {
                string dirToMatch = dirEnumerator[index].directory;

                if (Regex.IsMatch(dirToMatch, pattern, RegexOptions.IgnoreCase))
                {
                    if (!firstmatch)
                    {
                        firstmatch = true;
                        firstMatchIndex = index;
                    }
                    else
                    {
                        directory.totalDirectoriesCount += dirEnumerator[index].directoriesCount;
                        directory.totalFilesCount += dirEnumerator[index].filesCount;
                    }

                    directory.totalSizeGB += dirEnumerator[index].sizeGB;
                }
                else if (firstmatch)
                {
                    match = false;
                    index = firstMatchIndex;
                }

                index++;
            }
        }
    }

    public class directoryInfo : IComparable<directoryInfo>
    {
        public string directory;
        public int directoriesCount;
        public Dictionary<string, long> files = new Dictionary<string, long>();
        public int filesCount;
        public float sizeGB;
        public int totalDirectoriesCount;
        public int totalFilesCount;
        public float totalSizeGB;

        int IComparable<directoryInfo>.CompareTo(directoryInfo other)
        {
            // fix string sort 'git' vs 'git lb' when there are subdirs comparing space to \ and set \ to 29
            string compareDir = new String(directory.ToCharArray().Select(ch => ch <= (char)47 ? (char)29 : ch).ToArray());
            string otherCompareDir = new String(other.directory.ToCharArray().Select(ch => ch <= (char)47 ? (char)29 : ch).ToArray());
            return String.Compare(compareDir, otherCompareDir, true);
        }
    }
}
'@

try
{
    Add-Type $code
    main
}
catch
{
    write-host "main exception: $($error | out-string)"   
    $error.Clear()
}
finally
{
    [dotnet]::_directories.clear()
    $script.directories = $Null

    if ($script:logStream)
    {
        $script:logStream.Close() 
        $script:logStream = $null
    }
}






