# setup-github.ps1 - Script per preparare automaticamente il progetto per GitHub
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "fastapi-aws-tutorial"
)

Write-Host "🚀 Setup automatico progetto GitHub" -ForegroundColor Cyan
Write-Host "Username: $GitHubUsername" -ForegroundColor Green
Write-Host "Progetto: $ProjectName" -ForegroundColor Green
Write-Host ""

# Lista dei file da aggiornare
$filesToUpdate = @(
    "README.md",
    ".github/FUNDING.yml",
    ".github/dependabot.yml",
    "GITHUB_SETUP.md"
)

Write-Host "📝 Aggiornamento placeholder nei file..." -ForegroundColor Yellow

foreach ($file in $filesToUpdate) {
    if (Test-Path $file) {
        Write-Host "  Aggiornando $file..." -ForegroundColor Gray
        
        # Leggi il contenuto
        $content = Get-Content $file -Raw -Encoding UTF8
        
        # Sostituisci i placeholder
        $content = $content -replace 'YOUR_USERNAME', $GitHubUsername
        $content = $content -replace 'fastapi-aws-tutorial', $ProjectName
        
        # Scrivi il file aggiornato
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText((Resolve-Path $file), $content, $utf8NoBom)
        
        Write-Host "    ✅ $file aggiornato" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️  $file non trovato" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🔧 Configurazione Git..." -ForegroundColor Yellow

# Inizializza git se non già fatto
if (-not (Test-Path ".git")) {
    git init
    Write-Host "  ✅ Repository Git inizializzato" -ForegroundColor Green
} else {
    Write-Host "  ✅ Repository Git già esistente" -ForegroundColor Green
}

# Aggiungi remote se non esiste
$remoteUrl = "https://github.com/$GitHubUsername/$ProjectName.git"
try {
    $currentRemote = git remote get-url origin 2>$null
    if ($currentRemote -ne $remoteUrl) {
        git remote set-url origin $remoteUrl
        Write-Host "  ✅ Remote origin aggiornato: $remoteUrl" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Remote origin già configurato" -ForegroundColor Green
    }
} catch {
    git remote add origin $remoteUrl
    Write-Host "  ✅ Remote origin aggiunto: $remoteUrl" -ForegroundColor Green
}

Write-Host ""
Write-Host "📋 Creazione file di configurazione aggiuntivi..." -ForegroundColor Yellow

# Crea .gitattributes se non esiste
if (-not (Test-Path ".gitattributes")) {
    @"
# Auto detect text files and perform LF normalization
* text=auto

# Custom for Visual Studio
*.cs     diff=csharp

# Standard to msysgit
*.doc	 diff=astextplain
*.DOC	 diff=astextplain
*.docx diff=astextplain
*.DOCX diff=astextplain
*.dot  diff=astextplain
*.DOT  diff=astextplain
*.pdf  diff=astextplain
*.PDF	 diff=astextplain
*.rtf	 diff=astextplain
*.RTF	 diff=astextplain

# Python
*.py text eol=lf
*.pyx text eol=lf
*.pxd text eol=lf
*.pxi text eol=lf

# Shell scripts
*.sh text eol=lf
*.bash text eol=lf

# Batch files
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf

# Markdown
*.md text eol=lf

# YAML
*.yml text eol=lf
*.yaml text eol=lf

# JSON
*.json text eol=lf

# Docker
Dockerfile text eol=lf
*.dockerfile text eol=lf

# Ignore files
.gitignore text eol=lf
.gitattributes text eol=lf
"@ | Out-File -FilePath ".gitattributes" -Encoding UTF8
    Write-Host "  ✅ .gitattributes creato" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎯 Verifica finale..." -ForegroundColor Yellow

# Verifica che tutti i file importanti esistano
$requiredFiles = @(
    "README.md",
    "CONTRIBUTING.md", 
    "CHANGELOG.md",
    "LICENSE",
    "requirements.txt",
    "Dockerfile",
    ".gitignore",
    ".github/workflows/ci.yml"
)

$allGood = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file MANCANTE!" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
if ($allGood) {
    Write-Host "🎉 Setup completato con successo!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Prossimi passi:" -ForegroundColor Cyan
    Write-Host "  1. Crea il repository su GitHub: https://github.com/new" -ForegroundColor White
    Write-Host "  2. Nome repository: $ProjectName" -ForegroundColor White
    Write-Host "  3. Esegui i seguenti comandi:" -ForegroundColor White
    Write-Host ""
    Write-Host "     git add ." -ForegroundColor Gray
    Write-Host "     git commit -m `"Initial commit - FastAPI AWS Tutorial`"" -ForegroundColor Gray
    Write-Host "     git branch -M main" -ForegroundColor Gray
    Write-Host "     git push -u origin main" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Configura il repository seguendo GITHUB_SETUP.md" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 URL del tuo repository: https://github.com/$GitHubUsername/$ProjectName" -ForegroundColor Cyan
} else {
    Write-Host "❌ Setup incompleto. Controlla i file mancanti sopra." -ForegroundColor Red
}

Write-Host ""
Write-Host "Made with ❤️  for GitHub" -ForegroundColor Magenta