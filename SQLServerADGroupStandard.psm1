function New-DatabaseADGroupCollection {
<# 
 .Synopsis
  Facilitates creation of standard Active Directory security groups for SQL Server databases.

 .Description
  Creates standard groups accorting to a static naming convention in Active Directory. 
  The function creates groups with names based on the name of the database server or Availability Group name.

 .Parameter ServerInstanceName
  Name of the SQL Server instance, e.g. ServerName/InstanceName or ServerName. The ServerInstanceName patameter can also be a Availability Group name, e.g. AG01.

 .Parameter DatabaseName
  The name of the database for which the groups are to be created.

 .Parameter OUPath
  The Organizational Unit (OU) path in Active Directory where the groups will be created, e.g. "OU=DatabaseGroups,DC=subdomain,DC=example,DC=com"

 .Parameter AddGroupsToSQLServer
  Add this parameter to add the created groups as logins and users in SQL Server.

 .Example
   # Add database groups in Active Directory and SQL Server.
   New-DatabaseADGroupCollection -ServerInstanceName "Server01\Instance01" -DatabaseName "Database01" -OUPath "OU=DatabaseGroups,DC=subdomain,DC=example,DC=com" -AddGroupsToSQLServer
#>
[CmdletBinding()]
param(
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [String]$ServerInstanceName,

        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [String]$DatabaseName,

        [Parameter(Mandatory=$True)]
        [String]$OUPath,

        [Parameter(Mandatory=$false)]
        [Switch]$AddGroupsToSQLServer = $false
    )

    BEGIN {
        if ($env:USERDOMAIN -eq $env:COMPUTERNAME) {
        Write-Error -Message "You must be logged on to an Active Directory domain"
        break
    }
    
    }
    PROCESS {
        $groupBaseName = "db"
        if ($ServerInstanceName -match "\\") {
            $comlpeteName = $ServerInstanceName.Split("\")
            $groupBaseName = "$groupBaseName.$($comlpeteName[0].ToLower()).$($comlpeteName[1].ToLower()).$($databaseName.ToLower())"
        } else {
            $groupBaseName = "$groupBaseName.$($ServerInstanceName.ToLower()).$($DatabaseName.ToLower())"
        }
        $readerGroupName = "$groupBaseName.r"
        $readerWriteExecutorGroupName = "$groupBaseName.rwe"
        $ownerGroupName = "$groupBaseName.dbo"

        $groups = @()
        $groups += $readerGroupName
        $groups += $readerWriteExecutorGroupName
        $groups += $ownerGroupName

        foreach ($groupName in $groups) {
            try {
                $newGroup = Get-ADGroup $groupName -ErrorAction SilentlyContinue
                Write-Information "The group $groupName already exist in Active Directory"
            } catch {
                $newGroup = New-ADGroup -Name $groupName -Path $OUPath -GroupScope Global -GroupCategory Security
            }
            if ($AddGroupsToSQLServer -eq $True) {
                    $addLoginQuery = "IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = '$($env:USERDOMAIN)\$groupName') BEGIN CREATE LOGIN [$($env:USERDOMAIN)\$groupName] FROM WINDOWS END"
                    Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database "master" -Query $addLoginQuery
                    $addUserQuery = "IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$($env:USERDOMAIN)\$groupName') BEGIN CREATE USER [$($env:USERDOMAIN)\$groupName] FOR LOGIN [$($env:USERDOMAIN)\$groupName] END"
                    Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $addUserQuery
            }
        
        }
        #Adding reader group
        $readerQuery = "IF IS_ROLEMEMBER ('db_datareader', '$($env:USERDOMAIN)\$readerGroupName') = 0 BEGIN ALTER ROLE [db_datareader] ADD MEMBER [$($env:USERDOMAIN)\$readerGroupName] END"
        Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $readerQuery

        #Adding reader-writer-executor group
        $readerWriterExecutorQuery = "IF IS_ROLEMEMBER ('db_datareader', '$($env:USERDOMAIN)\$readerWriteExecutorGroupName') = 0 BEGIN ALTER ROLE [db_datareader] ADD MEMBER [$($env:USERDOMAIN)\$readerWriteExecutorGroupName] END"
        Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $readerWriterExecutorQuery
        $readerWriterExecutorQuery = "IF IS_ROLEMEMBER ('db_datawriter', '$($env:USERDOMAIN)\$readerWriteExecutorGroupName') = 0 BEGIN ALTER ROLE [db_datawriter] ADD MEMBER [$($env:USERDOMAIN)\$readerWriteExecutorGroupName] END"
        Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $readerWriterExecutorQuery 
        $readerWriterExecutorQuery = "IF EXISTS (SELECT name FROM sys.database_principals WHERE name = 'db_executor' AND type = 'R') BEGIN IF IS_ROLEMEMBER ('db_executor', '$($env:USERDOMAIN)\$readerWriteExecutorGroupName') = 0 BEGIN ALTER ROLE [db_executor] ADD MEMBER [$($env:USERDOMAIN)\$readerWriteExecutorGroupName] END END"
        Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $readerWriterExecutorQuery

        #Adding database owner group
        $ownerQuery = "IF IS_ROLEMEMBER ('db_owner', '$($env:USERDOMAIN)\$ownerGroupName') = 0 BEGIN ALTER ROLE [db_owner] ADD MEMBER [$($env:USERDOMAIN)\$ownerGroupName] END"
        Invoke-Sqlcmd -ServerInstance $ServerInstanceName -Database $DatabaseName -Query $ownerQuery
 
    }
    END {
    }
}