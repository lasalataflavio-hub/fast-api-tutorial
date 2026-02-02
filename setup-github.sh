#!/bin/bash
# setup-github.sh - Script per preparare automaticamente il progetto per GitHub

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parametri
GITHUB_USERNAME=""
PROJECT_NAME="fastapi-aws-tutorial"

# Funzione per mostrare l'help
show_help() {
    echo -e "${CYAN}🚀 Setup automatico progetto GitHub${NC}"
    echo ""
    echo "Uso: $0 -u <github-username> [-p <project-name>]"
    echo ""
    echo "Opzioni:"
    echo "  -u, --username    Username GitHub (obbligatorio)"
    echo "  -p, --project     Nome del progetto (default: fastapi-aws-tutorial)"
    echo "  -h, --help        Mostra questo help"
    echo ""
    echo "Esempio:"
    echo "  $0 -u mio-username"
    echo "  $0 -u mio-username -p mio-progetto-aws"
}

# Parse parametri
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            GITHUB_USERNAME="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Parametro sconosciuto: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verifica parametri obbligatori
if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED}❌ Username GitHub obbligatorio!${NC}"
    show_help
    exit 1
fi

echo -e "${CYAN}🚀 Setup automatico progetto GitHub${NC}"
echo -e "${GREEN}Username: $GITHUB_USERNAME${NC}"
echo -e "${GREEN}Progetto: $PROJECT_NAME${NC}"
echo ""

# Lista dei file da aggiornare
files_to_update=(
    "README.md"
    ".github/FUNDING.yml"
    ".github/dependabot.yml"
    "GITHUB_SETUP.md"
)

echo -e "${YELLOW}📝 Aggiornamento placeholder nei file...${NC}"

for file in "${files_to_update[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${NC}Aggiornando $file...${NC}"
        
        # Sostituisci i placeholder usando sed
        sed -i.bak "s/YOUR_USERNAME/$GITHUB_USERNAME/g" "$file"
        sed -i.bak "s/fastapi-aws-tutorial/$PROJECT_NAME/g" "$file"
        
        # Rimuovi file di backup
        rm -f "$file.bak"
        
        echo -e "    ${GREEN}✅ $file aggiornato${NC}"
    else
        echo -e "    ${YELLOW}⚠️  $file non trovato${NC}"
    fi
done

echo ""
echo -e "${YELLOW}🔧 Configurazione Git...${NC}"

# Inizializza git se non già fatto
if [ ! -d ".git" ]; then
    git init
    echo -e "  ${GREEN}✅ Repository Git inizializzato${NC}"
else
    echo -e "  ${GREEN}✅ Repository Git già esistente${NC}"
fi

# Aggiungi remote se non esiste
remote_url="https://github.com/$GITHUB_USERNAME/$PROJECT_NAME.git"
if git remote get-url origin &>/dev/null; then
    current_remote=$(git remote get-url origin)
    if [ "$current_remote" != "$remote_url" ]; then
        git remote set-url origin "$remote_url"
        echo -e "  ${GREEN}✅ Remote origin aggiornato: $remote_url${NC}"
    else
        echo -e "  ${GREEN}✅ Remote origin già configurato${NC}"
    fi
else
    git remote add origin "$remote_url"
    echo -e "  ${GREEN}✅ Remote origin aggiunto: $remote_url${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Creazione file di configurazione aggiuntivi...${NC}"

# Crea .gitattributes se non esiste
if [ ! -f ".gitattributes" ]; then
    cat > .gitattributes << 'EOF'
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
EOF
    echo -e "  ${GREEN}✅ .gitattributes creato${NC}"
fi

echo ""
echo -e "${YELLOW}🎯 Verifica finale...${NC}"

# Verifica che tutti i file importanti esistano
required_files=(
    "README.md"
    "CONTRIBUTING.md"
    "CHANGELOG.md"
    "LICENSE"
    "requirements.txt"
    "Dockerfile"
    ".gitignore"
    ".github/workflows/ci.yml"
)

all_good=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✅ $file${NC}"
    else
        echo -e "  ${RED}❌ $file MANCANTE!${NC}"
        all_good=false
    fi
done

echo ""
if [ "$all_good" = true ]; then
    echo -e "${GREEN}🎉 Setup completato con successo!${NC}"
    echo ""
    echo -e "${CYAN}📋 Prossimi passi:${NC}"
    echo -e "  ${NC}1. Crea il repository su GitHub: https://github.com/new${NC}"
    echo -e "  ${NC}2. Nome repository: $PROJECT_NAME${NC}"
    echo -e "  ${NC}3. Esegui i seguenti comandi:${NC}"
    echo ""
    echo -e "     ${NC}git add .${NC}"
    echo -e "     ${NC}git commit -m \"Initial commit - FastAPI AWS Tutorial\"${NC}"
    echo -e "     ${NC}git branch -M main${NC}"
    echo -e "     ${NC}git push -u origin main${NC}"
    echo ""
    echo -e "  ${NC}4. Configura il repository seguendo GITHUB_SETUP.md${NC}"
    echo ""
    echo -e "${CYAN}🔗 URL del tuo repository: https://github.com/$GITHUB_USERNAME/$PROJECT_NAME${NC}"
else
    echo -e "${RED}❌ Setup incompleto. Controlla i file mancanti sopra.${NC}"
fi

echo ""
echo -e "${MAGENTA}Made with ❤️  for GitHub${NC}"