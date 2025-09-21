# LibreChat auf Azure Container Apps

Diese Anleitung zeigt, wie Sie LibreChat auf Azure Container Apps deployen können.

## 🚀 Schnellstart

Für eine vollautomatische Einrichtung führen Sie einfach aus:

```bash
./azure-complete-setup.sh
```

## 📋 Voraussetzungen

- Azure CLI installiert und konfiguriert
- Docker installiert
- Azure Subscription mit entsprechenden Berechtigungen

## 🔧 Manuelle Einrichtung

### 1. Azure Storage Setup

```bash
./azure-storage-setup.sh
```

Dieses Skript erstellt:
- Azure Storage Account
- File Shares für persistente Daten
- Konfiguration für MongoDB, Meilisearch, PostgreSQL

### 2. Azure Key Vault Setup

```bash
./azure-keyvault-setup.sh
```

Dieses Skript erstellt:
- Azure Key Vault
- Sichere Speicherung von Secrets
- Konfiguration für MongoDB, PostgreSQL, Meilisearch

### 3. Azure Container Registry Setup

```bash
./azure-container-registry-setup.sh
```

Dieses Skript erstellt:
- Azure Container Registry
- Lädt alle erforderlichen Images hoch
- Konfiguriert Registry-Zugriff

### 4. Azure Container Apps Deployment

```bash
./azure-deploy.sh
```

Dieses Skript erstellt:
- Container Apps Environment
- Alle LibreChat Services
- Netzwerk-Konfiguration
- Load Balancer

## 🏗️ Architektur

Die Azure Container Apps Lösung besteht aus:

- **LibreChat API**: Hauptanwendungs-Container
- **LibreChat Client**: Nginx Frontend
- **MongoDB**: Datenbank für Benutzer und Konversationen
- **Meilisearch**: Such-Engine
- **PostgreSQL**: Vector Database für RAG
- **RAG API**: Retrieval-Augmented Generation Service

## 🔐 Sicherheit

- Alle Secrets werden in Azure Key Vault gespeichert
- Container-to-Container Kommunikation über interne Netzwerke
- Externe Zugriffe nur über Load Balancer
- SSL/TLS Verschlüsselung

## 📊 Monitoring

- Azure Monitor für Metriken
- Application Insights für Logs
- Container Health Checks
- Auto-Scaling basierend auf CPU/Memory

## 💾 Persistente Daten

- MongoDB Daten: Azure Files
- Meilisearch Indizes: Azure Files
- PostgreSQL Daten: Azure Files
- Upload-Dateien: Azure Files
- Logs: Azure Files

## 🔧 Konfiguration

### Umgebungsvariablen

Die wichtigsten Umgebungsvariablen:

```bash
HOST=0.0.0.0
NODE_ENV=production
PORT=3080
MONGO_URI=mongodb://mongodb:27017/LibreChat
MEILI_HOST=http://meilisearch:7700
RAG_PORT=8000
RAG_API_URL=http://rag-api:8000
```

### LibreChat Konfiguration

Die `librechat.yaml` wird über ConfigMap bereitgestellt und kann angepasst werden.

## 🚨 Troubleshooting

### Häufige Probleme

1. **Container startet nicht**
   - Prüfen Sie die Logs: `az containerapp logs show`
   - Überprüfen Sie die Umgebungsvariablen
   - Prüfen Sie die Registry-Zugriffsberechtigungen

2. **Datenbank-Verbindungsfehler**
   - Überprüfen Sie die Key Vault Secrets
   - Prüfen Sie die Netzwerk-Konfiguration
   - Überprüfen Sie die MongoDB/PostgreSQL Container

3. **Speicher-Probleme**
   - Überprüfen Sie die Azure Files Konfiguration
   - Prüfen Sie die Persistent Volume Claims
   - Überprüfen Sie die Storage Account Berechtigungen

### Logs anzeigen

```bash
# API Logs
az containerapp logs show --name librechat-api --resource-group librechat-rg

# MongoDB Logs
az containerapp logs show --name librechat-mongodb --resource-group librechat-rg

# Alle Container Logs
az containerapp logs show --name librechat-api --resource-group librechat-rg --follow
```

## 📈 Skalierung

### Auto-Scaling

Container Apps unterstützen automatische Skalierung basierend auf:
- CPU-Auslastung
- Memory-Verbrauch
- HTTP-Anfragen
- Custom Metriken

### Manuelle Skalierung

```bash
# Replicas erhöhen
az containerapp update --name librechat-api --resource-group librechat-rg --min-replicas 2 --max-replicas 5

# CPU/Memory erhöhen
az containerapp update --name librechat-api --resource-group librechat-rg --cpu 1.0 --memory 2.0Gi
```

## 🔄 Updates

### Container Images aktualisieren

```bash
# Neues Image zu Registry pushen
docker tag ghcr.io/danny-avila/librechat-dev-api:latest your-registry.azurecr.io/librechat-api:latest
docker push your-registry.azurecr.io/librechat-api:latest

# Container App aktualisieren
az containerapp update --name librechat-api --resource-group librechat-rg --image your-registry.azurecr.io/librechat-api:latest
```

## 💰 Kostenoptimierung

- Verwenden Sie Basic SKU für Container Registry
- Konfigurieren Sie Auto-Scaling für optimale Ressourcennutzung
- Verwenden Sie Standard_LRS für Storage (günstiger als Premium)
- Überwachen Sie die Kosten mit Azure Cost Management

## 🆘 Support

Bei Problemen:

1. Überprüfen Sie die Azure Container Apps Logs
2. Prüfen Sie die Key Vault Secrets
3. Überprüfen Sie die Netzwerk-Konfiguration
4. Kontaktieren Sie den Azure Support

## 📚 Weitere Ressourcen

- [Azure Container Apps Dokumentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [LibreChat Dokumentation](https://docs.librechat.ai/)
- [Azure Key Vault Dokumentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Azure Storage Dokumentation](https://docs.microsoft.com/en-us/azure/storage/)
