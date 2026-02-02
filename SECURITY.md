# Security Policy

## Reporting Security Issues

Se trovi una vulnerabilità di sicurezza in questo progetto, ti preghiamo di NON aprire una issue pubblica.

Invece, invia una email a: [inserisci la tua email] con:
- Descrizione della vulnerabilità
- Passi per riprodurla
- Impatto potenziale

## Best Practices per l'Uso

Questo è un progetto **didattico**. Se lo usi in produzione, assicurati di:

### 🔒 Credenziali AWS

- ✅ **MAI** committare file `.env.local` con credenziali reali
- ✅ Usa sempre IAM roles invece di access keys quando possibile
- ✅ Abilita MFA per gli utenti AWS
- ✅ Ruota regolarmente le credenziali
- ✅ Usa il principio del "least privilege" per le policy IAM

### 🔐 Secrets Management

- ✅ Usa AWS Secrets Manager per tutti i secrets
- ✅ Abilita la rotazione automatica dei secrets
- ✅ Cripta i secrets con KMS customer managed keys
- ✅ Non loggare mai valori sensibili

### 🛡️ Network Security

- ✅ Usa HTTPS per tutte le comunicazioni (App Runner lo fa di default)
- ✅ Configura Security Groups appropriati se usi VPC
- ✅ Abilita AWS WAF per protezione da attacchi comuni (opzionale)

### 📊 Monitoring

- ✅ Abilita CloudTrail per audit logging
- ✅ Configura allarmi CloudWatch per attività sospette
- ✅ Monitora i costi AWS per rilevare uso anomalo

### 🔄 Updates

- ✅ Mantieni aggiornate le dipendenze Python (`pip list --outdated`)
- ✅ Aggiorna regolarmente l'immagine Docker base
- ✅ Monitora le CVE per le librerie usate

## Vulnerabilità Note

### Progetto Didattico

Questo progetto è pensato per **scopi educativi**. Per uso in produzione:

1. **Autenticazione**: Aggiungi autenticazione (JWT, OAuth2) agli endpoints
2. **Rate Limiting**: Implementa rate limiting per prevenire abuse
3. **Input Validation**: Aggiungi validazione più rigorosa degli input
4. **CORS**: Configura CORS policies appropriate
5. **Secrets**: Non usare secrets di esempio in produzione

## Dipendenze

Le dipendenze sono specificate in `requirements.txt`. Verifica regolarmente per vulnerabilità:

```bash
# Usa pip-audit per controllare vulnerabilità
pip install pip-audit
pip-audit
```

## Compliance

Se usi questo progetto in ambienti regolamentati:

- 🏥 **HIPAA**: Richiede configurazioni aggiuntive (encryption, audit, etc.)
- 💳 **PCI-DSS**: Richiede controlli di sicurezza specifici
- 🇪🇺 **GDPR**: Assicurati di gestire correttamente i dati personali

## Risorse

- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
