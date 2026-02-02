FROM python:3.14-slim

# Imposta la directory di lavoro nel container
WORKDIR /code

# Copia il file delle dipendenze prima del resto del codice per sfruttare la cache di Docker
COPY requirements.txt .

# Installa le dipendenze
# Usiamo --no-cache-dir per ridurre la dimensione dell'immagine
# Usiamo --upgrade pip per assicurarci di avere l'ultima versione di pip
RUN pip install --no-cache-dir --upgrade pip -r requirements.txt

# Copia il resto del codice dell'applicazione (la directory 'app') mantenendo la struttura
COPY ./app ./app

# Esponi la porta su cui Uvicorn ascolterà
EXPOSE 8000

# Comando per eseguire l'applicazione Uvicorn
# Ascolta su 0.0.0.0 per essere accessibile dall'esterno del container
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
