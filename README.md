# Seguimiento al Graduado

Aplicación Flutter conectada a Supabase para seguimiento de graduados. Conserva un cliente único para Android y Web, con una experiencia según la plataforma y el rol:

| Rol | APK | Web |
|---|---|---|
| `SUPER_ADMIN` | Home de graduado | Dashboard administrativo |
| `ADMINISTRADOR` | Home de graduado | Dashboard administrativo |
| `GRADUADO` | Home de graduado | Home de graduado; sin acceso administrativo |

## Configuración local

`config/local.json` se mantiene fuera de Git. Cree una copia de la plantilla y agregue únicamente `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (la clave `anon` legacy también es pública). No use claves `service_role` en el cliente.

```bash
cp config/local.example.json config/local.json
# Complete la URL y la clave pública en config/local.json
flutter pub get
flutter run --dart-define-from-file=config/local.json
```

Si falta la configuración, la aplicación muestra una pantalla explicativa; no arranca con datos simulados.

## Supabase

La base y sus políticas existentes se describen en `supabase/01_schema_y_rls.sql`. Para habilitar las estadísticas agregadas del dashboard, ejecute además `supabase/02_admin_dashboard_stats.sql` en el SQL Editor de Supabase. La función reutiliza `obtener_rol_usuario()`, corre con permisos del invocador y no modifica RLS.

Las estadísticas de egreso y departamento se omiten si esas columnas no tienen datos. La distribución de respuestas se calcula para las opciones seleccionadas (incluye checkbox); las respuestas de texto libre no tienen categorías y no se representan como distribución.

## Compilación

```bash
flutter build apk --release --dart-define-from-file=config/local.json
flutter build web --release --dart-define-from-file=config/local.json
```

También se pueden inyectar variables en CI mediante `--dart-define`:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA
```

Cloudflare Pages debe publicar `build/web`. Flutter Web genera una SPA y el archivo `web/_redirects` configura el fallback de rutas. Configure `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` como variables de entorno de build en Pages y use `bash scripts/build_web_cloudflare.sh` como comando de build; no coloque secretos en los assets web.

## Funcionalidades

El Home de graduado contiene perfil, encuestas/responder, historial y recomendaciones. La Web administrativa añade estadísticas, resultados, gestión de recomendaciones y creación de encuestas. La app verifica sesión y rol con `obtener_rol_usuario()`; RLS sigue siendo la protección efectiva de los datos.
