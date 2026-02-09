#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

Describe "Bicep Module: Virtual Machine" {

    BeforeAll {
        $ModulePath = Split-Path -Parent $PSScriptRoot
        $TemplatePath = Join-Path $ModulePath "main.bicep"
        $ParametersPath = Join-Path $PSScriptRoot "test.parameters.json"
    }

    Context "Static Analysis" {

        It "Should have valid Bicep syntax" {
            $build = az bicep build --file $TemplatePath 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should generate ARM template" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            Test-Path $armTemplatePath | Should -Be $true
        }

        It "Should have a test parameters file" {
            Test-Path $ParametersPath | Should -Be $true
        }

        It "Should have valid JSON in test parameters" {
            { Get-Content $ParametersPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should have required sub-modules" {
            $requiredModules = @(
                'virtualMachine.bicep',
                'nic.bicep',
                'publicIp.bicep',
                'diagnostics.bicep',
                'lock.bicep',
                'rbac.bicep',
                'extensions.bicep'
            )
            foreach ($module in $requiredModules) {
                Test-Path (Join-Path $ModulePath "modules" $module) | Should -Be $true -Because "$module should exist"
            }
        }
    }

    Context "Template Validation" {

        It "Should have valid ARM template schema" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.'$schema' | Should -Not -BeNullOrEmpty
            $template.'$schema' | Should -BeLike '*deploymentTemplate*'
        }

        It "Should define workloadName parameter" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.workloadName | Should -Not -BeNullOrEmpty
            $template.parameters.workloadName.maxLength | Should -Be 10
        }

        It "Should define osType parameter with allowed values" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.osType.allowedValues | Should -Contain 'Windows'
            $template.parameters.osType.allowedValues | Should -Contain 'Linux'
        }

        It "Should define vmSize parameter" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.vmSize | Should -Not -BeNullOrEmpty
        }

        It "Should define adminUsername parameter" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.adminUsername | Should -Not -BeNullOrEmpty
        }

        It "Should define environment parameter with allowed values" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.environment.allowedValues | Should -Contain 'dev'
            $template.parameters.environment.allowedValues | Should -Contain 'test'
            $template.parameters.environment.allowedValues | Should -Contain 'prod'
        }

        It "Should define tags parameter" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.tags | Should -Not -BeNullOrEmpty
        }

        It "Should have test parameters for Linux VM" {
            $parameters = (Get-Content $ParametersPath -Raw | ConvertFrom-Json).parameters

            $parameters.osType.value | Should -Be 'Linux'
        }

        It "Test parameters should include imageReference" {
            $parameters = (Get-Content $ParametersPath -Raw | ConvertFrom-Json).parameters

            $parameters.imageReference.value.publisher | Should -Not -BeNullOrEmpty
            $parameters.imageReference.value.offer | Should -Not -BeNullOrEmpty
            $parameters.imageReference.value.sku | Should -Not -BeNullOrEmpty
        }

        It "Test parameters should include nicConfigs" {
            $parameters = (Get-Content $ParametersPath -Raw | ConvertFrom-Json).parameters

            $parameters.nicConfigs.value | Should -Not -BeNullOrEmpty
            $parameters.nicConfigs.value.Count | Should -BeGreaterOrEqual 1
        }

        It "Should define lockLevel parameter with allowed values" {
            $armTemplatePath = $TemplatePath -replace '\.bicep$', '.json'
            $template = Get-Content $armTemplatePath | ConvertFrom-Json

            $template.parameters.lockLevel.allowedValues | Should -Contain 'CanNotDelete'
            $template.parameters.lockLevel.allowedValues | Should -Contain 'ReadOnly'
        }

        It "Test parameters should include tags" {
            $parameters = (Get-Content $ParametersPath -Raw | ConvertFrom-Json).parameters

            $parameters.tags.value | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        Write-Host "Test cleanup completed"
    }
}
