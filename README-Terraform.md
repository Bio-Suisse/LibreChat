# Terraform Deployment für Bio Suisse AI Assistant

Dieses Terraform-Script deployt eine vollständige LibreChat-Infrastruktur auf Azure Container Apps.

## 🚀 Verbesserungen gegenüber der ursprünglichen Version

### ✅ Sicherheit
- **Keine hardcoded Passwörter mehr** - alle Passwörter werden über sichere Variablen verwaltet
- **Automatische Passwort-Generierung** falls keine angegeben werden
- **Key Vault Integration** für sichere Secret-Verwaltung
- **VNet-Integration** für isolierte Container-Kommunikation
- **System-assigned Identities** für sichere Secret-Zugriffe

### ✅ Persistente Speicher
- **Azure File Shares** für MongoDB, PostgreSQL und Meilisearch
- **Daten bleiben erhalten** bei Container-Neustarts
- **Optimierte Storage-Konfiguration** für bessere Performance

### ✅ Netzwerk-Konfiguration
- **VNet-Integration** für sichere interne Kommunikation
- **Interne Load Balancer** für Container-zu-Container Kommunikation
- **Korrekte FQDN-basierte Service-Discovery**
- **Externe Zugriff** nur für LibreChat API

### ✅ Vollständige Umgebungsvariablen
- **Alle notwendigen ENV-Vars** für LibreChat
- **OpenAI API Key** Integration
- **Automatische Domain-Konfiguration**
- **PostgreSQL-Verbindung** für RAG API
- **Meilisearch-Konfiguration** mit Master Key

### ✅ Health Checks & Monitoring
- **Liveness Probes** für alle Container Apps
- **Readiness Probes** für bessere Verfügbarkeit
- **Log Analytics Integration** für zentrale Überwachung
- **Automatische Container-Neustarts** bei Problemen

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
┌─────────────────────────────────────────────────────────────────┐
│                        Azure VNet (10.0.0.0/16)                │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │   LibreChat     │    │   RAG API        │    │ PostgreSQL │ │
│  │   (External)    │◄──►│   (Internal)     │◄──►│ (Internal) │ │
│  │   Port: 3080    │    │   Port: 8000     │    │ Port: 5432  │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│           │                       │                       │     │
│           ▼                       │                       │     │
│  ┌─────────────────┐              │                       │     │
│  │   MongoDB       │              │                       │     │
│  │   (Internal)    │              │                       │     │
│  │   Port: 27017   │              │                       │     │
│  └─────────────────┘              │                       │     │
│           │                       │                       │     │
│           ▼                       │                       │     │
│  ┌─────────────────┐              │                       │     │
│  │   Meilisearch   │              │                       │     │
│  │   (Internal)    │              │                       │     │
│  │   Port: 7700    │              │                       │     │
│  └─────────────────┘              │                       │     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Azure File Shares (Persistent Storage)        │ │
│  │  • mongo-data (10GB) • postgres-data (10GB) • meili-data  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Azure Key Vault (Secrets)                   │
│  • mongo-password • postgres-password • meili-master-key      │
│  • openai-api-key                                              │
└─────────────────────────────────────────────────────────────────┘
```

## 🗂️ Persistente Daten

Alle Daten werden in Azure File Shares gespeichert:
- **MongoDB**: `mongo-data` (10 GB)
- **PostgreSQL**: `postgres-data` (10 GB)  
- **Meilisearch**: `meili-data` (5 GB)

## 🔐 Sicherheit

- **Key Vault** für alle Secrets mit automatischer Rotation
- **System-assigned Identities** für Container Apps
- **VNet-Integration** für isolierte Container-Kommunikation
- **Interne Load Balancer** für sichere Service-Discovery
- **Externe Zugriff** nur für LibreChat API
- **Health Checks** für automatische Container-Neustarts
- **Log Analytics** für zentrale Überwachung und Alerting

## 🧹 Cleanup

```bash
terraform destroy
```

## ⚠️ Wichtige Hinweise

1. **OpenAI API Key** ist erforderlich für LibreChat
2. **Passwörter** werden automatisch generiert falls nicht angegeben
3. **Container Apps** brauchen einige Minuten zum Starten
4. **Erste Anfrage** kann länger dauern (Cold Start)
5. **VNet-Integration** erfordert zusätzliche Berechtigungen
6. **Health Checks** starten nach 30-60 Sekunden
7. **Interne Kommunikation** erfolgt über FQDN-basierte Service Discovery

## 🐛 Troubleshooting

### Container startet nicht
- Prüfe die Logs in Azure Portal → Container Apps → Logs
- Überprüfe die Umgebungsvariablen in der Container-Konfiguration
- Stelle sicher, dass alle Secrets im Key Vault verfügbar sind
- Prüfe die Health Check-Konfiguration

### Verbindungsprobleme
- Prüfe die FQDN-basierten Service-Namen in den ENV-Vars
- Überprüfe die VNet-Integration und Subnet-Konfiguration
- Stelle sicher, dass alle Container Apps laufen
- Prüfe die interne Load Balancer-Konfiguration

### Health Check-Probleme
- Prüfe die Health Check-Endpunkte (/health, /api/health)
- Überprüfe die Timeout-Konfigurationen
- Stelle sicher, dass die Container vollständig initialisiert sind

### Performance-Probleme
- Erhöhe CPU/Memory Limits in der Terraform-Konfiguration
- Überprüfe die Storage-Performance der Azure File Shares
- Prüfe die Netzwerk-Latenz zwischen Container Apps
- Überwache die Log Analytics für Performance-Metriken
