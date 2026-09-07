# Kiosko

Webapp para un local tipo kiosko (tragos, comida). El cliente escanea un QR,
arma su pedido, paga (Mercado Pago / transferencia / efectivo) y elige retiro
en el local o delivery. La pantalla del local recibe los pedidos nuevos en
tiempo real.

## Stack

- Vue 3 (Composition API) + Vite + Tailwind v4 (`@tailwindcss/vite`) + Vue Router
- Supabase (`@supabase/supabase-js`): Postgres + Auth + Realtime + Storage
- Supabase Edge Functions para el webhook de Mercado Pago
- Deploy: Hostinger (SPA estática), mismo pipeline que `asiste`

## Arrancar en local

1. `npm install`
2. Copiar `.env.example` a `.env` y completar con los datos del proyecto Supabase
   (Supabase → Project Settings → API).
3. `npm run dev`

## Estructura

```
src/
├── lib/supabase.js      cliente Supabase (lee credenciales del .env)
├── router/index.js      rutas: / (carta), /local (pantalla del local)
├── views/Carta.vue      cara al cliente
├── views/Local.vue      pantalla interna (KDS)
└── App.vue              layout + chequeo de conexión
public/.htaccess         fallback SPA para Apache/Hostinger
```

## Base de datos

El esquema vive versionado en `supabase/migrations/*.sql` y se aplica con la
Supabase CLI (`npx supabase db push --db-url "$SUPABASE_DB_URL"`), usando la
connection string del **Session pooler** (no la conexión directa: en el free
tier es IPv6-only). Las credenciales de conexión están en
`.env.supabase-cli` (gitignorado, no se sube nunca).

El avance del proyecto se lleva en [`PROGRESO.md`](./PROGRESO.md).
