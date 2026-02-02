# Contributing to FastAPI AWS Tutorial

Grazie per il tuo interesse nel contribuire a questo progetto didattico! 🎉

## Come Contribuire

### 🐛 Segnalare Bug

1. Controlla se il bug è già stato segnalato nelle [Issues](../../issues)
2. Se non esiste, crea una nuova issue con:
   - Descrizione chiara del problema
   - Passi per riprodurre il bug
   - Comportamento atteso vs comportamento attuale
   - Informazioni sull'ambiente (OS, Python version, AWS region)

### 💡 Suggerire Miglioramenti

1. Apri una [Issue](../../issues) con label "enhancement"
2. Descrivi chiaramente il miglioramento proposto
3. Spiega perché sarebbe utile per scopi didattici

### 🔧 Contribuire Codice

1. **Fork** il repository
2. **Clone** il tuo fork localmente
3. Crea un **branch** per la tua feature:
   ```bash
   git checkout -b feature/nome-feature
   ```
4. **Sviluppa** la tua feature
5. **Testa** le modifiche
6. **Commit** con messaggi chiari:
   ```bash
   git commit -m "Add: nuova funzionalità per gestire X"
   ```
7. **Push** al tuo fork:
   ```bash
   git push origin feature/nome-feature
   ```
8. Apri una **Pull Request**

## 📋 Linee Guida

### Codice

- Segui le convenzioni Python (PEP 8)
- Usa type hints
- Documenta le funzioni con docstring
- Mantieni il codice semplice e didattico
- Aggiungi commenti per spiegare logica complessa

### Documentazione

- Aggiorna la documentazione per nuove feature
- Usa esempi pratici e chiari
- Mantieni il tono didattico e accessibile
- Includi esempi di comandi AWS CLI quando necessario

### Commit Messages

Usa il formato:
- `Add: nuova funzionalità`
- `Fix: correzione bug`
- `Update: aggiornamento esistente`
- `Docs: aggiornamento documentazione`

## 🧪 Testing

Prima di inviare una PR:

1. Testa localmente con Docker:
   ```bash
   docker build -t fastapi-tutorial .
   docker run -p 8000:8000 fastapi-tutorial
   ```

2. Verifica che la documentazione sia accessibile:
   ```bash
   curl http://localhost:8000/docs
   ```

3. Se possibile, testa con AWS reale

## 📚 Aree di Contribuzione

### Priorità Alta
- Miglioramenti alla documentazione
- Esempi di codice più chiari
- Correzioni di bug
- Miglioramenti alla sicurezza

### Priorità Media
- Nuovi esercizi per studenti
- Ottimizzazioni performance
- Supporto per nuove regioni AWS
- Miglioramenti UX

### Priorità Bassa
- Nuove feature avanzate
- Integrazioni con altri servizi AWS
- Supporto per altri cloud provider

## ❓ Domande

Se hai domande:
1. Controlla la [documentazione](docs/)
2. Cerca nelle [Issues](../../issues) esistenti
3. Apri una nuova issue con label "question"

## 📄 Licenza

Contribuendo, accetti che i tuoi contributi siano rilasciati sotto la stessa licenza MIT del progetto.

---

Grazie per aiutare a migliorare questo progetto didattico! 🚀