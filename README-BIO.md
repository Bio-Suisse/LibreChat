# LibreChat Bio Suisse - Deployment & Wartung

Diese Dokumentation beschreibt, wie der Bio Suisse LibreChat Fork gewartet, aktualisiert und deployt wird.

## 📋 Inhaltsverzeichnis

1. [GitHub Fork aktualisieren](#1-github-fork-aktualisieren)
2. [Konfiguration anpassen](#2-konfiguration-anpassen)
3. [Docker Images erstellen und deployen](#3-docker-images-erstellen-und-deployen)
4. [Konfigurationsänderungen aktivieren](#4-konfigurationsänderungen-aktivieren)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. GitHub Fork aktualisieren

### 1.1 Remote-Repositories einrichten

Stellen Sie sicher, dass Sie beide Remotes konfiguriert haben:

```bash
# Original LibreChat Repository (upstream)
git remote add upstream https://github.com/danny-avila/LibreChat.git

# Bio Suisse Fork (origin)
git remote -v
# Sollte zeigen:
# origin    https://github.com/bio-suisse/LibreChat.git (fetch)
# origin    https://github.com/bio-suisse/LibreChat.git (push)
# upstream  https://github.com/danny-avila/LibreChat.git (fetch)
# upstream  https://github.com/danny-avila/LibreChat.git (push)
```

### 1.2 Updates vom Original Repository holen

```bash
# Aktuelle Änderungen committen (falls vorhanden)
git add .
git commit -m "Local changes before merge"

# Main Branch wechseln
git checkout main

# Updates vom Original Repository holen
git fetch upstream

# Aktuellen Stand anzeigen
git log HEAD..upstream/main --oneline

# Updates in den eigenen Fork mergen
git merge upstream/main

# Falls es Merge-Konflikte gibt, diese auflösen:
# git status  # Zeigt Konflikte
# # Bearbeiten Sie die betroffenen Dateien
# git add .
# git commit -m "Merge upstream/main - Konflikte gelöst"
```

### 1.3 Bio Suisse-spezifische Änderungen beibehalten

Wichtige Dateien, die Sie möglicherweise anpassen müssen:

- `librechat.yaml` - Bio Suisse spezifische Konfiguration
- `main.tf` - Terraform-Konfiguration für Azure
- `terraform.tfvars` - Ihre spezifischen Variablen
- Eventuelle Custom-Anpassungen

**Empfehlung:** Verwenden Sie Git Branches für Custom-Anpassungen:

```bash
# Branch für Bio Suisse Anpassungen erstellen
git checkout -b bio-suisse-customizations

# Ihre Anpassungen machen
# ...

# In main mergen, wenn stabil
git checkout main
git merge bio-suisse-customizations
```

### 1.4 Änderungen zum Fork pushen

```bash
# Änderungen zum Bio Suisse Fork pushen
git push origin main

# Falls Sie einen Feature-Branch haben:
git push origin bio-suisse-customizations
```

---

## 2. Konfiguration anpassen

### 2.1 LibreChat YAML Konfiguration

Die Hauptkonfigurationsdatei ist `librechat.yaml`. Bearbeiten Sie diese lokal:

```bash
# Konfiguration öffnen
code librechat.yaml
# oder
vim librechat.yaml
```

#### Wichtige Konfigurationsoptionen:

```yaml
version: 1.2.1
cache: true

interface:
  customWelcome: 'Willkommen beim Bio Suisse AI Assistant!'
  endpointsMenu: false  # Nur OpenAI anzeigen
  modelSelect: true
  parameters: true

endpoints:
  openAI:
    models:
      default: 'gpt-5'
      chatCompletion: 'gpt-5'
    availableModels:
      - 'gpt-5'
    titleConvo: true
    titleModel: 'gpt-5'
    summarize: true
    summaryModel: 'gpt-5'
    modelDisplayLabel: 'GPT-5'
```

**Wichtig:** Der Endpoint-Key muss `openAI` (camelCase) sein, nicht `openai`!

### 2.2 Terraform Variablen

Für Azure-spezifische Einstellungen bearbeiten Sie `terraform.tfvars`:

```bash
code terraform.tfvars
```

Beispiel:
```hcl
location = "switzerlandnorth"
resource_group_name = "bioaiassist-rg"
# ... weitere Variablen
```

### 2.3 Environment-Variablen (Optional)

Die meisten Konfigurationen können auch über Environment-Variablen gesetzt werden (siehe `main.tf`):

- `APP_TITLE` - Anwendungs-Titel
- `ALLOW_REGISTRATION` - Registrierung erlauben
- `DOMAIN_CLIENT` / `DOMAIN_SERVER` - Domain-Konfiguration
- `OPENAI_API_KEY` - API-Schlüssel (aus Key Vault)
- etc.

Komplexere UI/Interface-Einstellungen benötigen jedoch die `librechat.yaml`.

---

## 3. Docker Images erstellen und deployen

### 3.1 Voraussetzungen

```bash
# Azure CLI Login
az login

# Docker installiert und laufend
docker --version

# Terraform installiert
terraform --version
```

### 3.2 Azure Container Registry Informationen

Erhalten Sie die ACR-Details:

```bash
# Resource Group Name
RG_NAME="bioaiassist-rg"

# ACR Name aus Terraform Output
ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "bioaiassistacr...")
# oder direkt aus Azure:
ACR_NAME=$(az acr list --resource-group $RG_NAME --query "[0].name" -o tsv)

echo "ACR Name: $ACR_NAME"
```

### 3.3 Docker Image lokal erstellen

#### Option A: Multi-Stage Build (Empfohlen)

```bash
# API Image erstellen
docker build \
  --target api-build \
  -f Dockerfile.multi \
  -t ${ACR_NAME}.azurecr.io/librechat-api:latest \
  -t ${ACR_NAME}.azurecr.io/librechat-api:$(git rev-parse --short HEAD) \
  .

# Full Image erstellen (falls benötigt)
docker build \
  --target node \
  -f Dockerfile \
  -t ${ACR_NAME}.azurecr.io/librechat:latest \
  -t ${ACR_NAME}.azurecr.io/librechat:$(git rev-parse --short HEAD) \
  .
```

#### Option B: Dev Image (für Entwicklung)

```bash
# Dev API Image
docker build \
  --target api-build \
  -f Dockerfile.multi \
  -t ${ACR_NAME}.azurecr.io/librechat-dev-api:latest \
  .

# Dev Full Image
docker build \
  --target node \
  -f Dockerfile \
  -t ${ACR_NAME}.azurecr.io/librechat-dev:latest \
  .
```

### 3.4 Bei Azure Container Registry anmelden

```bash
# Login bei ACR
az acr login --name $ACR_NAME
```

### 3.5 Images zu Azure Container Registry pushen

```bash
# API Image pushen
docker push ${ACR_NAME}.azurecr.io/librechat-api:latest
docker push ${ACR_NAME}.azurecr.io/librechat-api:$(git rev-parse --short HEAD)

# Full Image pushen (falls erstellt)
docker push ${ACR_NAME}.azurecr.io/librechat:latest
docker push ${ACR_NAME}.azurecr.io/librechat:$(git rev-parse --short HEAD)
```

**Tipp:** Verwenden Sie Version-Tags basierend auf Git Commits oder Versionsnummern:

```bash
VERSION=$(git describe --tags --always)
docker tag ${ACR_NAME}.azurecr.io/librechat-api:latest \
           ${ACR_NAME}.azurecr.io/librechat-api:$VERSION
docker push ${ACR_NAME}.azurecr.io/librechat-api:$VERSION
```

### 3.6 Terraform aktualisieren

Aktualisieren Sie `main.tf` mit dem neuen Image:

```terraform
resource "azurerm_container_app" "librechat_api" {
  # ...
  template {
    container {
      name  = "librechat-api"
      # Alte Image-Referenz ersetzen:
      # image = "ghcr.io/danny-avila/librechat-dev:latest"
      image = "${azurerm_container_registry.main.login_server}/librechat-api:latest"
      # oder mit Version:
      # image = "${azurerm_container_registry.main.login_server}/librechat-api:${var.image_version}"
    }
  }
}
```

### 3.7 Terraform Apply ausführen

```bash
# Plan anzeigen
terraform plan

# Änderungen anwenden
terraform apply
```

Die Container App wird automatisch mit dem neuen Image aktualisiert.

### 3.8 Deployment Status prüfen

```bash
# Revision Status prüfen
az containerapp revision list \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --query "[0].{name:name, active:properties.active, status:properties.runningState, health:properties.healthState}" \
  --output table

# Logs prüfen
az containerapp logs show \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --follow false \
  --tail 50
```

---

## 4. Konfigurationsänderungen aktivieren

### 4.1 LibreChat.yaml aktualisieren

#### Schritt 1: Datei lokal bearbeiten

```bash
# LibreChat.yaml öffnen
code librechat.yaml
# oder
vim librechat.yaml
```

#### Schritt 2: Änderungen validieren

```bash
# YAML Syntax prüfen (optional, falls yq installiert)
yq eval '.' librechat.yaml

# Oder mit Python
python3 -c "import yaml; yaml.safe_load(open('librechat.yaml'))"
```

**Wichtig:** Stellen Sie sicher, dass:
- `version` korrekt ist (aktuell: `1.2.1`)
- Endpoint-Keys camelCase sind (`openAI`, nicht `openai`)
- YAML-Syntax korrekt ist (Einrückungen beachten!)

#### Schritt 3: Datei zu Azure File Share hochladen

```bash
# Storage Account Name aus Terraform
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "bioaiassist")

# Storage Key holen
STORAGE_KEY=$(az storage account keys list \
  --resource-group $RG_NAME \
  --account-name $STORAGE_ACCOUNT \
  --query "[0].value" -o tsv)

# Alte Datei löschen (optional)
az storage file delete \
  --account-name $STORAGE_ACCOUNT \
  --account-key "$STORAGE_KEY" \
  --share-name librechat-config \
  --path librechat.yaml

# Neue Datei hochladen
az storage file upload \
  --account-name $STORAGE_ACCOUNT \
  --account-key "$STORAGE_KEY" \
  --share-name librechat-config \
  --source librechat.yaml \
  --path librechat.yaml

# Upload prüfen
az storage file list \
  --account-name $STORAGE_ACCOUNT \
  --account-key "$STORAGE_KEY" \
  --share-name librechat-config \
  --output table
```

#### Schritt 4: Container App neu starten

```bash
# Aktuelle Revision finden
REVISION=$(az containerapp revision list \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --query "[0].name" -o tsv)

# Revision neu starten
az containerapp revision restart \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --revision $REVISION
```

#### Schritt 5: Logs prüfen

```bash
# 30 Sekunden warten, dann Logs prüfen
sleep 30

az containerapp logs show \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --follow false \
  --tail 100 | grep -E "(Config|customWelcome|endpointsMenu|loaded|valid|Invalid)"

# Erfolgreiche Meldungen sollten enthalten:
# "Custom config file loaded:"
# "customWelcome": "Willkommen beim Bio Suisse AI Assistant!"
```

### 4.2 Environment-Variablen aktualisieren

Falls Sie Environment-Variablen ändern müssen:

```bash
# main.tf bearbeiten
code main.tf

# Terraform Plan
terraform plan -target=azurerm_container_app.librechat_api

# Terraform Apply
terraform apply -target=azurerm_container_app.librechat_api
```

### 4.3 Schnellreferenz: Komplettes Update-Skript

```bash
#!/bin/bash
# update-config.sh

set -e

RG_NAME="bioaiassist-rg"
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "bioaiassist")

echo "📝 Lade librechat.yaml hoch..."

STORAGE_KEY=$(az storage account keys list \
  --resource-group $RG_NAME \
  --account-name $STORAGE_ACCOUNT \
  --query "[0].value" -o tsv)

# Upload
az storage file delete \
  --account-name $STORAGE_ACCOUNT \
  --account-key "$STORAGE_KEY" \
  --share-name librechat-config \
  --path librechat.yaml 2>/dev/null || true

az storage file upload \
  --account-name $STORAGE_ACCOUNT \
  --account-key "$STORAGE_KEY" \
  --share-name librechat-config \
  --source librechat.yaml \
  --path librechat.yaml

echo "🔄 Starte Container App neu..."

REVISION=$(az containerapp revision list \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --query "[0].name" -o tsv)

az containerapp revision restart \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --revision $REVISION

echo "✅ Update abgeschlossen! Prüfe Logs mit:"
echo "az containerapp logs show --name bio-ai-librechat-api --resource-group $RG_NAME --follow false --tail 50"
```

---

## 5. Troubleshooting

### 5.1 Config wird nicht geladen

**Problem:** Logs zeigen "Invalid custom config file" oder "Config version: undefined"

**Lösung:**
1. YAML-Syntax prüfen (Einrückungen, korrekte Keys)
2. Endpoint-Keys müssen camelCase sein (`openAI`, nicht `openai`)
3. Datei neu hochladen und Container neu starten

```bash
# YAML validieren
python3 -c "import yaml; yaml.safe_load(open('librechat.yaml'))"

# Datei im Container prüfen (falls möglich)
az containerapp exec --name bio-ai-librechat-api --resource-group $RG_NAME --command "cat /app/config/librechat.yaml"
```

### 5.2 Image Build schlägt fehl

**Problem:** Docker Build Error

**Lösung:**
1. Docker-Space prüfen: `docker system df`
2. Cache löschen: `docker builder prune`
3. Build ohne Cache: `docker build --no-cache ...`

### 5.3 Container startet nicht

**Problem:** Revision Status zeigt "Failed" oder "Unhealthy"

**Lösung:**
```bash
# Detaillierte Logs prüfen
az containerapp logs show \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --follow false \
  --tail 200

# Revision-Details
az containerapp revision show \
  --name bio-ai-librechat-api \
  --resource-group $RG_NAME \
  --revision <REVISION_NAME>
```

### 5.4 MongoDB Verbindungsfehler

**Problem:** "Server selection timed out" oder "Authentication failed"

**Lösung:**
1. MongoDB Status prüfen:
```bash
az containerapp show --name bio-ai-mongodb --resource-group $RG_NAME
```

2. MONGO_URI in main.tf prüfen (muss `authSource=admin` enthalten)

3. MongoDB neu starten falls nötig

### 5.5 Config-Änderungen werden nicht übernommen

**Problem:** Änderungen in librechat.yaml werden nicht angewendet

**Lösung:**
1. Datei wurde hochgeladen? Prüfen:
```bash
az storage file list --account-name $STORAGE_ACCOUNT --account-key "$STORAGE_KEY" --share-name librechat-config
```

2. CONFIG_PATH ist korrekt? Prüfen:
```bash
az containerapp show --name bio-ai-librechat-api --resource-group $RG_NAME --query "properties.template.containers[0].env[?name=='CONFIG_PATH']"
```

3. Container neu gestartet? Siehe Abschnitt 4.1, Schritt 4

---

## 🔗 Wichtige Links

- **Original LibreChat:** https://github.com/danny-avila/LibreChat
- **LibreChat Dokumentation:** https://docs.librechat.ai
- **Azure Container Apps:** https://docs.microsoft.com/en-us/azure/container-apps/
- **Terraform Azure Provider:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs

---

## 📝 Checkliste für Updates

- [ ] GitHub Fork aktualisiert (`git merge upstream/main`)
- [ ] Konflikte aufgelöst (falls vorhanden)
- [ ] `librechat.yaml` angepasst (falls nötig)
- [ ] Docker Images erstellt
- [ ] Images zu ACR gepusht
- [ ] Terraform `main.tf` aktualisiert (Image-Referenz)
- [ ] `terraform apply` ausgeführt
- [ ] Deployment Status geprüft
- [ ] Logs geprüft (keine Fehler)
- [ ] Anwendung getestet

---

## 🎯 Best Practices

1. **Versions-Kontrolle:** Verwenden Sie Git Tags für wichtige Releases
2. **Backup:** Vor größeren Updates ein Backup der Config erstellen
3. **Testing:** Änderungen erst lokal testen, dann deployen
4. **Monitoring:** Logs regelmäßig prüfen nach Deployment
5. **Dokumentation:** Änderungen dokumentieren für das Team

---

**Stand:** November 2025  
**Version:** 1.0  
**Verantwortlich:** Bio Suisse IT-Team

