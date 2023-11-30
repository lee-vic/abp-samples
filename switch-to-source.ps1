$abp_framework_dir = "F:\git_repositories\abp\framework\src"
$abp_modules_dir = "F:\git_repositories\abp\modules"
$abp_framework_projects_dict = @{}
$abp_modules_projects_dict = @{}
$abp_framework_projects = Get-ChildItem -Path $abp_framework_dir -Recurse  -Include *.csproj
foreach ($project in $abp_framework_projects) {
    $abp_framework_projects_dict.Add($project.BaseName, $project.FullName)
}
$abp_modules_projects = Get-ChildItem -Path $abp_modules_dir -Recurse  -Include *.csproj
foreach ($mod in $abp_modules_projects) {
    $abp_modules_projects_dict.Add($mod.BaseName, $mod.FullName)
}


function AddSourceToProjects($project_file) {
    #得到项目的包引用
    $package_matches = Select-String -Path $project_file -Pattern "(?<=PackageReference Include="").*?(?="")";
    if ($package_matches.Matches.Count -gt 0) {
        foreach ($package_match in $package_matches) {
            $package_name = $package_match.Matches[0].Value;
            if ($package_name -like "*Volo*") {
                $find_result = $abp_framework_projects_dict.ContainsKey($package_name)
                #框架的源码中找到了
                if ($true -eq $find_result) {
                    #移除包引用
                    dotnet remove  $project_file package $package_name;
                    #添加项目引用
                    dotnet add $project_file reference  $abp_framework_projects_dict[$package_name]
                }
                else {
                    #框架源码中没有,查找模块的源码
                    $find_result = $abp_modules_projects_dict.ContainsKey($package_name)
                    #模块的源码中找到了
                    if ($true -eq $find_result) {
                        #移除包引用
                        dotnet remove  $project_file package $package_name;
                        #添加项目引用
                        dotnet add $project_file reference   $abp_modules_projects_dict[$package_name]
                    }
                }
                
            }
        }
    }
}

function AddSourceToSolution($sln_file, $project_file, $ref_projects_list) {

    $current_dir = (Get-Location).Path;
    $project_file_dir = (Get-Item $project_file).DirectoryName;
    Set-Location $project_file_dir;

    $reference_projects = dotnet list $project_file reference
    $result_type = $reference_projects.GetType();
    #没有项目应用的时候返回的类型是一个字符串
    if ($result_type.Name -ne "String") {
        foreach ($reference_project in $reference_projects) {
            if (($reference_project.Length -gt 6) -and ($reference_project.Contains("Volo"))) {
                $reference_project_path = (Resolve-Path $reference_project).Path;
                if (!$ref_projects_list.Contains($reference_project_path)) {
                    if ($reference_project_path.Contains("\framework\")) {
                        dotnet sln $sln_file add $reference_project_path --solution-folder abp/framework
                    }
                    else {
                        dotnet sln $sln_file add $reference_project_path --solution-folder abp/modules
                    }
                    $ref_projects_list.Add($reference_project_path);
                }
                else {
                    $message = ("total count:", $ref_projects_list.Count, ".already exist:", $reference_project) -join ""
                    Write-Host $message
                }
                #递归检查
                #AddSourceToSolution $sln_file $reference_project_path $ref_projects_list
            }
        }
    }
    Set-Location $current_dir;
}
#找到解决方案文件
$sln_files = Get-ChildItem -Path . -Recurse -Filter "*.sln"
$root_dir = (Get-Location).Path;
#遍历解决方案文件
foreach ($sln_file in $sln_files) {
    #解决方案文件所在目录
    $sln_file_dir = $sln_file.DirectoryName;
    Set-Location $sln_file_dir
    #得到解决方案下的所有项目
    $sln_projects = dotnet sln $sln_file.FullName list
    foreach ($sln_project in $sln_projects) {
        if ($sln_project.Length -gt 3) {
            #解析出项目的绝对路径
            $sln_project_path = Resolve-Path $sln_project;
            AddSourceToProjects $sln_project_path.Path
        }
    }
    Set-Location $root_dir
}
foreach ($sln_file in $sln_files) {
    #解决方案文件所在目录
    $sln_file_dir = $sln_file.DirectoryName;

    Set-Location $sln_file_dir
    $ref_projects_list = New-Object System.Collections.Generic.List[System.String]
    #重复执行多次，达到近于递归的效果，递归执行性能太差
    for ($i = 0; $i -le 5; $i++ ) {
        #得到解决方案下的所有项目
        $sln_projects = dotnet sln $sln_file.FullName list
        foreach ($sln_project in $sln_projects) {
            if ($sln_project.Length -gt 3) {
                #解析出项目的绝对路径
                $sln_project_path = Resolve-Path $sln_project;
                AddSourceToSolution $sln_file.FullName $sln_project_path.Path $ref_projects_list
            }
        }
    }
    Set-Location $root_dir
}
abp clean
dotnet clean