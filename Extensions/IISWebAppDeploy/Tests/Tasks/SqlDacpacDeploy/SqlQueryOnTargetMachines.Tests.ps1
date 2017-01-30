﻿$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDirName = Split-Path -Leaf $currentScriptPath
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$VerbosePreference = 'Continue'

$sqlQueryOnTargetMachinesPath = "$currentScriptPath\..\..\..\Src\Tasks\$scriptDirName\TaskModuleSqlUtility\$sut"

if(-not (Test-Path -Path $sqlQueryOnTargetMachinesPath ))
{
    throw [System.IO.FileNotFoundException] "Unable to find SqlQueryOnTargetMachinesPath.ps1 at $sqlQueryOnTargetMachinesPath"
}

. "$sqlQueryOnTargetMachinesPath"

# Tests ----------------------------------------------------------------------------

Describe "Tests for verifying Import-SqlPs functionality" {

    Context "When Import execution fails" {

        $errMsg = "Module Not Found"
        Mock Import-SqlPs { throw $errMsg}
        
        try
        {
            Import-SqlPs
        }
        catch
        {
            $result = $_
        }
        
        It "should throw exception" {
            ($result.Exception.ToString().Contains("$errMsg")) | Should Be $true
        }
    }

    Context "When command execution successful" {

        Mock Import-SqlPs { return }

        try
        {
            Import-SqlPs
        }
        catch
        {
            $result = $_
        }
        
        It "should not throw exception" {
            $result.Exception | Should Be $null
        }
    }
}

Describe "Tests for verifying Execute-SqlQueryDeployment functionality" {

    Context "When execute sql is invoked with all inputs for Inline Sql"{


        Mock Test-Path { return $true }
        Mock Import-SqlPs { return }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }
        Mock Invoke-Sqlcmd -Verifiable { return }
    
        Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" 

        It "Should deploy inline Sql"{
            Assert-VerifiableMocks
            Assert-MockCalled Import-SqlPs -Times 1
            Assert-MockCalled Get-SqlFilepathOnTargetMachine -Times 1
            Assert-MockCalled Invoke-Sqlcmd -Times 1
        }
    }

    Context "When execute sql is invoked with additional arguments for Inline Sql"{


        Mock Test-Path { return $true }
        Mock Remove-Item { return }
        Mock Import-SqlPs { return }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }
        Mock Invoke-Sqlcmd -Verifiable { return } -ParameterFilter {$QueryTimeout -eq 50}
    
        Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" -additionalArguments "-QueryTimeout 50 wrongParam"

        It "Should have valid additional arguments"{
            Assert-VerifiableMocks
            Assert-MockCalled Import-SqlPs -Times 1
            Assert-MockCalled Get-SqlFilepathOnTargetMachine -Times 1
            Assert-MockCalled Invoke-Sqlcmd -Times 1
        }
    }

     Context "When execute sql is invoked with additional arguments with special character for Inline Sql"{

        Mock Test-Path { return $true }
        Mock Import-SqlPs { return }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }
        Mock Invoke-Sqlcmd -Verifiable { return } -ParameterFilter {$variable -eq "var1=user`$test"}
        Mock Remove-Item { return }

        Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" -additionalArguments "-variable var1=user`$test"

        It "Should have valid additional arguments with special character"{
            Assert-VerifiableMocks
            Assert-MockCalled Import-SqlPs -Times 1
            Assert-MockCalled Get-SqlFilepathOnTargetMachine -Times 1
            Assert-MockCalled Invoke-Sqlcmd -Times 1
        }
    }

    Context "When execute sql is invoked with Wrong Extension Sql File"{

        Mock Import-SqlPs { return }
        Mock Invoke-Expression -Verifiable { return } -ParameterFilter {$Command -and $Command.StartsWith("Invoke-Sqlcmd")}

        Mock Remove-Item { return }
        Mock Test-Path { return $true }

        try
        {
            Execute-SqlQueryDeployment -taskType "sqlQuery" -sqlFile "SampleFile.temp" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" 
        }
        catch
        {
            $result = $_
        }

        It "should throw exception" {
            ($result.Exception.ToString().Contains("Invalid Sql file [ SampleFile.temp ] provided")) | Should Be $true
        }
    }

    Context "When execute sql is invoked with Server Auth Type"{

        $secureAdminPassword =  ConvertTo-SecureString "SqlPass" -AsPlainText -Force
        $psCredential = New-Object System.Management.Automation.PSCredential ("SqlUser", $secureAdminPassword)

        Mock Test-Path { return $true }
        Mock Import-SqlPs { return }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }
        Mock Invoke-Sqlcmd -Verifiable { return } -ParameterFilter {($Username -eq "SqlUser") -and ($Password -eq "SqlPass")}

        Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" -sqlServerCredentials $psCredential -authscheme sqlServerAuthentication

        It "Should deploy inline Sql with Server Authetication"{
            Assert-VerifiableMocks
            Assert-MockCalled  Import-SqlPs -Times 1
            Assert-MockCalled  Get-SqlFilepathOnTargetMachine -Times 1
            Assert-MockCalled  Invoke-Sqlcmd -Times 1
        }
    }

    Context "When finally gets called and Test-Path Fails"{

        Mock Import-SqlPs { throw }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }

        # Marking Test Path as false so that Remove -Item is not called 
        # This tests Finally Part
        Mock Test-Path { return $false }
        Mock Remove-Item { return }

        try
        {
            Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" 
        }
        catch
        {
            # Do Nothing
        }

        It "Should deploy inline Sql"{
            Assert-VerifiableMocks
            Assert-MockCalled Test-Path -Times 1
            Assert-MockCalled Remove-Item -Times 0
        }
    }

    Context "When finally gets called and Test-Path Returns True"{

        Mock Import-SqlPs { throw }
        Mock Get-SqlFilepathOnTargetMachine { return "C:\sample.temp" }

        # Marking Test Path as true so that Remove -Item is called 
        # This tests Finally Part
        Mock Test-Path { return $true }
        Mock Remove-Item { return }

        try
        {
            Execute-SqlQueryDeployment -taskType "sqlInline" -inlineSql "SampleQuery" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB" 
        }
        catch
        {
            # Do Nothing
        }

        It "Should deploy inline Sql"{
            Assert-VerifiableMocks
            Assert-MockCalled Test-Path -Times 1
            Assert-MockCalled Remove-Item -Times 1
        }
    }

    Context "When execute sql is invoked with Sql File, Finally is no Op"{

        Mock Import-SqlPs { throw }

        Mock Remove-Item { return }
        Mock Test-Path { return $true }

        try
        {
            Execute-SqlQueryDeployment -taskType "sqlQuery" -sqlFile "SampleFile.temp" -targetMethod "server" -serverName "localhost" -databaseName "SampleDB"
        }
        catch
        {
            # Do Nothing
        }

        It "Should Short Circuit in Finally" {
            Assert-VerifiableMocks
            Assert-MockCalled Test-Path -Times 0
            Assert-MockCalled Remove-Item -Times 0
        }
    }    
}