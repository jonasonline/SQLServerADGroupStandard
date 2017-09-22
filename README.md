# SQLServerADGroupStandard
Module to add Active Directory security groups for SQL Server database access management.

## Usage
The function `New-DatabaseADGroupCollection` takes String input for ServerInstanceName and DatabaseName from pipeline or parameter.
The resulting groups follows the naming convention: 

* db.*servername*.[*instancename*].databasename.r - Group with membership in the **db_datareader** database role.
* db.*servername*.[*instancename*].databasename.rwe - Group with membership in the **db_datareader**, **db_datawriter** and **db_executor** (if it exists) database roles.
* db.*servername*.[*instancename*].databasename.dbo - Group with membership in the **db_owner** database role.

By default the groups are only created in Active Directory, but they can also be added to the databases by using the parameter `-AddGroupsToSQLServer`.

### Example:

```powershell
 Import-Csv databases.csv | New-DatabaseADGroupCollection -OUPath "OU=DatabaseGroups,DC=subdomain,DC=example,DC=com" -AddGroupsToSQLServer
 ``` 