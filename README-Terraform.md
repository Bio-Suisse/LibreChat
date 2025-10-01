# Terraform Deployment für Bio Suisse AI Assistant

Dieses Terraform-Script deployt eine vollständige LibreChat-Infrastruktur auf Azure Container Apps.

## 🚀 Verbesserungen gegenüber der ursprünglichen Version

### ✅ Sicherheit
- **Keine hardcoded Passwörter mehr** - alle Passwörter werden über sichere Variablen verwaltet
- **Automatische Passwort-Generierung** falls keine angegeben werden
- **Key Vault Integration** für sichere Secret-Verwaltung

### ✅ Persistente Speicher
- **Azure File Shares** für MongoDB, PostgreSQL und Meilisearch
- **Daten bleiben erhalten** bei Container-Neustarts

### ✅ Netzwerk-Konfiguration
- **Korrigierte Service-Namen** für Container-Kommunikation
- **Interne Kommunikation** zwischen Services
- **Externe Zugriff** nur für LibreChat API

### ✅ Vollständige Umgebungsvariablen
- **Alle notwendigen ENV-Vars** für LibreChat
- **OpenAI API Key** Integration
- **Automatische Domain-Konfiguration**

## 📋 Voraussetzungen

1. **Azure CLI** installiert und konfiguriert
2. **Terraform** installiert (Version >= 1.0)
3. **Azure Subscription** mit entsprechenden Berechtigungen
4. **OpenAI API Key** für LibreChat

## 🛠️ Installation

### 1. Terraform initialisieren
```bash
terraform init
```

### 2. Variablen konfigurieren
```bash
# Kopiere die Beispiel-Datei
cp terraform.tfvars.example terraform.tfvars

# Bearbeite die Werte
nano terraform.tfvars
```

**Wichtige Variablen:**
- `openai_api_key`: Dein OpenAI API Key (erforderlich)
- `mongo_password`: Optional - wird automatisch generiert
- `meili_master_key`: Optional - wird automatisch generiert  
- `postgres_password`: Optional - wird automatisch generiert

### 3. Plan erstellen
```bash
terraform plan
```

### 4. Deployment ausführen
```bash
terraform apply
```

## 📊 Outputs

Nach dem Deployment erhältst du:
- **LibreChat URL**: Die öffentliche URL der Anwendung
- **Resource Group Name**: Name der Azure Resource Group
- **Storage Account**: Name des Storage Accounts
- **Key Vault**: Name des Key Vaults

## 🔧 Architektur

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   LibreChat     │    │   RAG API        │    │   PostgreSQL   │
│   (External)    │◄──►│   (Internal)     │◄──►│   (Internal)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       │                       │
┌─────────────────┐              │                       │
│   MongoDB       │              │                       │
│   (Internal)    │              │                       │
└─────────────────┘              │                       │
         │                       │                       │
         ▼                       │                       │
┌─────────────────┐              │                       │
│   Meilisearch   │              │                       │
│   (Internal)    │              │                       │
└─────────────────┘              │                       │
```

## 🗂️ Persistente Daten

Alle Daten werden in Azure File Shares gespeichert:
- **MongoDB**: `mongo-data` (10 GB)
- **PostgreSQL**: `postgres-data` (10 GB)  
- **Meilisearch**: `meili-data` (5 GB)

## 🔐 Sicherheit

- **Key Vault** für alle Secrets
- **System-assigned Identities** für Container Apps
- **Interne Kommunikation** zwischen Services
- **Externe Zugriff** nur für LibreChat

## 🧹 Cleanup

```bash
terraform destroy
```

## ⚠️ Wichtige Hinweise

1. **OpenAI API Key** ist erforderlich für LibreChat
2. **Passwörter** werden automatisch generiert falls nicht angegeben
3. **Container Apps** brauchen einige Minuten zum Starten
4. **Erste Anfrage** kann länger dauern (Cold Start)

## 🐛 Troubleshooting

### Container startet nicht
- Prüfe die Logs in Azure Portal
- Überprüfe die Umgebungsvariablen
- Stelle sicher, dass alle Secrets verfügbar sind

### Verbindungsprobleme
- Prüfe die Service-Namen in den ENV-Vars
- Überprüfe die Ingress-Konfiguration
- Stelle sicher, dass alle Container Apps laufen

### Performance-Probleme
- Erhöhe CPU/Memory Limits in der Terraform-Konfiguration
- Überprüfe die Storage-Performance
- Prüfe die Netzwerk-Latenz
