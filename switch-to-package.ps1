$abp_version = "7.2.1"
#把项目引用切换成包引用
function SwitchProjectReferencesToPackage($project_path) {
    $current_dir = Get-Location;
    #设置当前目录为参数文件所在的目录
    $project_dir = (Get-Item $project_path).DirectoryName;
    Set-Location $project_dir
    #得到当前项目的项目引用
    $reference_projects = dotnet list $project_path reference
    $result_type = $reference_projects.GetType();
    #没有项目应用的时候返回的类型是一个字符串
    if ($result_type.Name -ne "String") {
        foreach ($reference_project in $reference_projects) {
            if ($reference_project.Length -gt 6) {
                #如果是abp的项目，直接项目引用中删除，并切换为包引用
                if ($reference_project.Contains("\abp\")) {
                    dotnet remove $project_path reference $reference_project
                    $package_name = (Get-Item $reference_project).BaseName;
                    dotnet add package $package_name --no-restore --version $abp_version;
                }
                #不是abp的项目递归检查
                else {
                    $reference_project_path = Resolve-Path $reference_project;
                    SwitchProjectReferencesToPackage $reference_project_path
                }
            }
        }
    }
    Set-Location $current_dir
}
#存储当前文件夹下的所有项目文件:.csproj文件，后续检索，如果不是当前文件夹下的项目则从解决方案移除
$projects_dict = @{}
$all_projects = Get-ChildItem -Path . -Recurse  -Include *.csproj
foreach ($project in $all_projects) {
    if (!$projects_dict.ContainsKey($project.BaseName)) {
        $projects_dict.Add($project.BaseName, $project.FullName)
    }
}
#找到所有解决方案文件
$sln_files = Get-ChildItem -Path . -Recurse -Filter "*.sln"
$root_dir = Get-Location
foreach ($sln_file in $sln_files) {
    $sln_dir = $sln_file.Directory.FullName
    Set-Location $sln_dir;
    #得到当前解决方案下的所有项目
    $project_list = dotnet sln $sln_file.FullName list
    foreach ($current_project in $project_list) {
        if ($current_project.Length -gt 3) {
            #如果是abp的项目，直接从解决方案移除
            if ($current_project.Contains("\abp\")) {
                dotnet sln $sln_file.FullName remove $current_project
            }
            #不是abp的项目，递归检查是否有引用Abp源码，如果有，切换成包引用
            else {
                $current_project_path = Resolve-Path $current_project;
                SwitchProjectReferencesToPackage $current_project_path
                $file_name = (Get-Item $current_project_path).BaseName
                #如果不是当前文件夹下项目，则从解决方案移除
                $query = $projects_dict.ContainsKey($file_name);
                if ($false -eq $query) {
                    dotnet sln $sln_file.FullName remove $current_project
                }
            }
        }
    }
    
    Set-Location $sln_dir;
}
Set-Location $root_dir.Path
