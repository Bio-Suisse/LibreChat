# LibreChat Benutzerverwaltung - Anleitung

Diese Anleitung beschreibt, wie Sie Benutzer in LibreChat verwalten können.

## 📋 Inhaltsverzeichnis

1. [Admin-Rolle erhalten](#1-admin-rolle-erhalten)
2. [Benutzerverwaltung über die Web-UI](#2-benutzerverwaltung-über-die-web-ui)
3. [Benutzerverwaltung über CLI-Tools](#3-benutzerverwaltung-über-cli-tools)
4. [Benutzer per API verwalten](#4-benutzer-per-api-verwalten)

---

## 1. Admin-Rolle erhalten

### Automatische Admin-Vergabe

**Wichtig:** Der erste Benutzer, der sich in LibreChat registriert, erhält automatisch die **ADMIN**-Rolle.

Wenn Sie bereits einen Account haben, müssen Sie diesen Account zum Admin machen:

### Admin über CLI setzen

```bash
# In den Container einloggen oder lokal ausführen
# MongoDB Connection String aus Terraform:
MONGO_URI="mongodb://admin:PASSWORT@bio-ai-mongodb:27017/LibreChat?authSource=admin&directConnection=true"

# Mit Node.js direkt in MongoDB
node -e "
const mongoose = require('mongoose');
const { User } = require('./api/models');
mongoose.connect('$MONGO_URI').then(async () => {
  const user = await User.findOne({ email: 'IHRE_EMAIL@example.com' });
  if (user) {
    user.role = 'ADMIN';
    await user.save();
    console.log('✅ Benutzer wurde zum Admin gemacht');
  } else {
    console.log('❌ Benutzer nicht gefunden');
  }
  process.exit(0);
});
"
```

---

## 2. Benutzerverwaltung über die Web-UI

### 2.1 Admin-Panel öffnen

1. **Als Admin einloggen:**
   - Gehen Sie zu: `https://bio-ai-librechat-api.livelyflower-4f84a8ae.switzerlandnorth.azurecontainerapps.io`
   - Loggen Sie sich mit Ihrem Admin-Account ein

2. **Admin-Einstellungen finden:**
   - Klicken Sie auf das **Shield-Icon** (⚙️) in der oberen Leiste
   - Nur Admins sehen dieses Icon
   - Verfügbar in verschiedenen Bereichen:
     - **Prompts**: Admin-Settings für Prompt-Berechtigungen
     - **Agents**: Admin-Settings für Agent-Berechtigungen
     - **Memories**: Admin-Settings für Memory-Berechtigungen

### 2.2 Verfügbare Admin-Funktionen

**In der Web-UI können Admins:**

- ✅ **Rollenzuweisungen** verwalten (USER vs. ADMIN)
- ✅ **Berechtigungen** für Agents, Prompts, Memories setzen
- ✅ **System-Einstellungen** konfigurieren

**NICHT verfügbar in der Web-UI:**
- ❌ Benutzer erstellen/löschen
- ❌ Passwörter zurücksetzen
- ❌ Benutzerliste anzeigen

→ Diese Funktionen sind nur über CLI-Tools verfügbar.

---

## 3. Benutzerverwaltung über CLI-Tools

### 3.1 Voraussetzungen

```bash
# Im Projekt-Verzeichnis
cd /Users/andy/Projects/bio-suisse/LibreChat

# MongoDB Connection String setzen (aus Terraform)
export MONGO_URI="mongodb://admin:PASSWORT@bio-ai-mongodb:27017/LibreChat?authSource=admin&directConnection=true"

# Oder in .env Datei:
MONGO_URI="mongodb://admin:PASSWORT@bio-ai-mongodb:27017/LibreChat?authSource=admin&directConnection=true"
```

### 3.2 Benutzer erstellen

```bash
# Mit interaktiver Eingabe
npm run create-user

# Oder direkt mit Parametern
npm run create-user email@example.com "Max Mustermann" maxmustermann

# Mit Email-Verifizierung deaktivieren
npm run create-user email@example.com "Max Mustermann" maxmustermann --email-verified=false

# Passwort automatisch generieren lassen (wird angezeigt)
npm run create-user email@example.com "Max Mustermann" maxmustermann
# → Passwort wird generiert und angezeigt
```

**Beispiel:**
```bash
npm run create-user max@bio-suisse.ch "Max Müller" maxmueller
# Password: (leer lassen für Auto-Generation)
# Email verified? (Y/n): Y
```

### 3.3 Benutzer auflisten

```bash
npm run list-users
```

**Ausgabe:**
```
User List:
----------------------------------------
ID: 507f1f77bcf86cd799439011
Email: admin@bio-suisse.ch
Username: admin
Name: Admin User
Provider: local
Created: 2025-11-02T12:00:00.000Z
----------------------------------------
Total Users: 1
```

### 3.4 Passwort zurücksetzen

```bash
npm run reset-password

# Interaktive Eingabe:
# Enter user email: user@example.com
# Enter new password: NeuesPasswort123
# Confirm new password: NeuesPasswort123
```

### 3.5 Benutzer löschen

```bash
# Mit Email als Parameter
npm run delete-user user@example.com

# Oder interaktiv
npm run delete-user
# Email: user@example.com
# Really delete user and ALL their data? (y/N): y
# Also delete all transaction history? (y/N): y
```

**Achtung:** Löscht **alle** Daten des Benutzers:
- Konversationen
- Nachrichten
- Dateien
- Presets
- Balances (optional)
- Transactions (optional)

### 3.6 Benutzer sperren/bannen

```bash
# Benutzer für 60 Minuten sperren
npm run ban-user user@example.com 60

# Oder interaktiv
npm run ban-user
# Email: user@example.com
# Duration (in minutes): 120
```

### 3.7 Benutzer einladen (Invite)

```bash
npm run invite-user email@example.com
```

Erstellt einen Einladungslink für einen neuen Benutzer.

### 3.8 Benutzer-Statistiken anzeigen

```bash
npm run user-stats
```

Zeigt Statistiken über alle Benutzer an.

---

## 4. Benutzer per API verwalten

### 4.1 API-Zugriff

Die LibreChat API bietet auch Endpoints für Benutzerverwaltung (nur für Admins):

**Base URL:**
```
https://bio-ai-librechat-api.livelyflower-4f84a8ae.switzerlandnorth.azurecontainerapps.io/api
```

### 4.2 Verfügbare Endpoints

```bash
# Als Admin authentifizieren (JWT Token erforderlich)
TOKEN="ihr-jwt-token"

# Benutzer-Info abrufen
curl -H "Authorization: Bearer $TOKEN" \
  https://bio-ai-librechat-api.livelyflower-4f84a8ae.switzerlandnorth.azurecontainerapps.io/api/user

# Benutzer aktualisieren
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Neuer Name"}' \
  https://bio-ai-librechat-api.livelyflower-4f84a8ae.switzerlandnorth.azurecontainerapps.io/api/user
```

**Hinweis:** Die meisten Admin-Funktionen sind über die Web-UI oder CLI-Tools besser zugänglich.

---

## 5. Rollen und Berechtigungen

### 5.1 Rollen

LibreChat kennt zwei Hauptrollen:

1. **USER** (Standard)
   - Kann Chat verwenden
   - Kann eigene Konversationen verwalten
   - Kein Zugriff auf Admin-Einstellungen

2. **ADMIN**
   - Alle USER-Rechte
   - Zugriff auf Admin-Panel
   - Kann Rollen und Berechtigungen verwalten
   - Kann System-Einstellungen ändern

### 5.2 Benutzer zurücksetzen

```bash
# Passwort zurücksetzen
npm run reset-password

# User komplett löschen und neu erstellen
npm run delete-user user@example.com
npm run create-user user@example.com "Neuer Name" username
```

---

## 6. Best Practices

### 6.1 Sicherheit

- ✅ **Starke Passwörter** verwenden (mind. 8 Zeichen)
- ✅ **Email-Verifizierung** aktivieren
- ✅ **Admin-Accounts** nur für vertrauenswürdige Personen
- ✅ **Regelmäßig** Benutzer-Liste prüfen

### 6.2 Empfohlene Workflows

**Neuen Benutzer hinzufügen:**
```bash
# 1. Benutzer erstellen
npm run create-user newuser@bio-suisse.ch "Name" username

# 2. Passwort an Benutzer übermitteln (sicher!)
# 3. Benutzer sollte beim ersten Login Passwort ändern
```

**Benutzer-Probleme lösen:**
```bash
# Passwort-Reset
npm run reset-password

# Bei schweren Problemen: Benutzer löschen und neu erstellen
npm run delete-user problematic@example.com
npm run create-user problematic@example.com "Name" username
```

**Regelmäßige Wartung:**
```bash
# Benutzer-Liste prüfen
npm run list-users

# Statistiken anzeigen
npm run user-stats
```

---

## 7. Troubleshooting

### Problem: "User not found"

**Lösung:**
```bash
# Prüfen Sie die Email-Adresse
npm run list-users | grep "email@example.com"

# Beachten Sie: Email ist case-insensitive
```

### Problem: "Cannot create admin user"

**Lösung:**
1. Ersten Benutzer registrieren (wird automatisch Admin)
2. Oder bestehenden Benutzer manuell zum Admin machen (siehe Abschnitt 1)

### Problem: "Permission denied" bei CLI-Tools

**Lösung:**
- Prüfen Sie die MongoDB-Verbindung
- Stellen Sie sicher, dass `MONGO_URI` korrekt gesetzt ist
- Prüfen Sie, ob Sie Zugriff auf die MongoDB-Instanz haben

### Problem: Admin-Icon nicht sichtbar

**Lösung:**
1. Prüfen Sie, ob Sie als Admin eingeloggt sind:
   ```bash
   npm run list-users | grep "your-email@example.com"
   # Sollte "role: ADMIN" zeigen (oder leer, wenn USER)
   ```

2. Falls nicht Admin: Siehe Abschnitt 1

---

## 8. Schnellreferenz

```bash
# Benutzer erstellen
npm run create-user email@example.com "Name" username

# Benutzer auflisten
npm run list-users

# Passwort zurücksetzen
npm run reset-password

# Benutzer löschen
npm run delete-user email@example.com

# Benutzer sperren
npm run ban-user email@example.com 60

# Statistiken
npm run user-stats
```

---

## 🔗 Weitere Ressourcen

- **LibreChat Dokumentation:** https://docs.librechat.ai
- **MongoDB Connection:** Prüfen Sie `main.tf` für den aktuellen Connection String
- **Admin-Panel:** Nur sichtbar für Admin-Rolle in der Web-UI

---

**Stand:** November 2025  
**Version:** 1.0  
**Verantwortlich:** Bio Suisse IT-Team

