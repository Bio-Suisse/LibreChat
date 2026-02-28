# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

LibreChat is an open-source AI chat platform (Node.js monorepo with npm workspaces). It consists of:

| Component | Path | Description |
|---|---|---|
| Backend API | `api/` | Express.js server on port 3080 |
| Frontend | `client/` | React + Vite SPA (dev server on port 3090, proxies `/api` to backend) |
| data-provider | `packages/data-provider/` | Shared types and API client |
| data-schemas | `packages/data-schemas/` | Mongoose schemas/models |
| @librechat/api | `packages/api/` | MCP services, auth, caching utilities |
| @librechat/client | `packages/client/` | Shared React components |

### Required services

- **MongoDB 7.0** must be running on `127.0.0.1:27017`. Start with: `sudo mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --fork`
- **Node.js 20.x** is required (see CONTRIBUTING.md). Use `nvm use 20`.

### Environment setup

- Copy `.env.example` to `.env` before starting the app. Set `SEARCH=false` unless MeiliSearch is running.
- Copy `librechat.example.yaml` to `librechat.yaml` for app configuration.
- Copy `api/test/.env.test.example` to `api/test/.env.test` before running API tests.

### Building & running

Packages must be built before the backend or frontend can run:

```
npm run build:packages
```

- **Backend dev** (with nodemon hot-reload): `npm run backend:dev` — serves the built client on port 3080.
- **Frontend dev** (with Vite HMR): `npm run frontend:dev` — runs on port 3090, proxies API calls to port 3080.
- The backend requires `client/dist/index.html` to exist. Run `npm run frontend` (builds client) before starting the backend if it hasn't been built yet.

### Testing

- **Lint**: `npm run lint` (full codebase lint is very slow ~3+ min; for quick checks use `npx eslint <file>`)
- **Backend unit tests**: `npm run test:api`
- **Frontend unit tests**: `npm run test:client`
- **E2E tests** (Playwright): `npm run e2e` — requires built client, MongoDB, and e2e config (`cp e2e/config.local.example.ts e2e/config.local.ts`).

See `.github/CONTRIBUTING.md` for full development setup and contribution guidelines.

### Gotchas

- After registering a user via the API, email verification must be set manually in MongoDB: `mongosh --eval "db.getSiblingDB('LibreChat').users.updateOne({email:'...'}, {\\$set: {emailVerified: true}})"`.
- The backend's nodemon config ignores `client/`, `packages/`, and `data/` directories. Changes to shared packages require rebuilding (`npm run build:packages`) and manually restarting the backend.
- MeiliSearch errors in the backend logs are safe to ignore when `SEARCH=false` is set; they come from the indexSync background task.
- Default `CREDS_KEY`, `CREDS_IV`, `JWT_SECRET`, and `JWT_REFRESH_SECRET` in `.env.example` produce warnings at startup but work for development.
