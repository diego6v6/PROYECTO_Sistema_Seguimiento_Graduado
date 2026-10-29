# Resumen de ejecución

**Fecha:** 2026-10-12 (inspección y comandos locales). **Aplicación/Supabase:** no se alcanzó ejecución funcional ni integración.

| Métrica | Funcionales | Seguridad | Total |
|---|---:|---:|---:|
| Casos definidos | 15 | 18 | 33 |
| APROBADO | 0 | 0 | 0 |
| FALLIDO | 0 | 0 | 0 |
| BLOQUEADO | 15 | 16 | 31 |
| NO IMPLEMENTADO | 0 | 0 | 0 |
| NO EJECUTADO | 0 | 2 | 2 |

SEG-06 y SEG-15 tuvieron revisión estática parcial del SQL, pero la validación dinámica permanece bloqueada; el estado se conserva como BLOQUEADO en el conteo. SEG-12 (escaneo de secretos) y SEG-16 (inyección con entradas) no llegaron a ejecutarse y constan NO EJECUTADO.

## Comandos ejecutados y observación

- `flutter test test` — comenzó sin emitir salida; proceso interrumpido. Sin resultado verificable.
- `flutter test test/unit --reporter expanded` — sin salida; interrumpido. Sin resultado verificable.
- `flutter --version` — sin salida en el tiempo disponible; interrumpido.
- `Get-Command flutter`, inspección de variables de entorno por nombre y revisión de archivos — Flutter está instalado; no aparecieron variables `SUPABASE_*`/`TEST_*`. No se consultaron ni imprimieron valores secretos.
- `Get-Command psql` — no disponible.

## Errores y límites

- Flutter CLI se quedó sin salida; por ello no se pudo comprobar ni siquiera la prueba unitaria local. No hay log original de Flutter porque la ejecución directa no se guardó a archivo.
- No hay URL/clave pública Supabase local, instancia aislada, cuentas configuradas, segundo graduado ni emulador/navegador controlado.
- Las credenciales temporales entregadas no bastan para determinar a qué instancia conectarse de forma segura. No se intentó iniciar sesión, acceder a producción ni cambiar roles.
- No se generaron capturas PNG; no hubo ejecución visual real.
- No se confirmó ninguna vulnerabilidad. SEG-07 es riesgo potencial, pendiente de validación aislada.

## Evidencias

- Casos funcionales: `test/functional/`.
- Casos de seguridad: `test/security/`.
- Esquema/RLS estático: `supabase/01_schema_y_rls.sql`.
- Reportes detallados: `resultados_CP01_CP15.md`, `resultados_CP01_CP15.csv`, `resultados_seguridad.md`.

## Addendum de ejecucion real (2026-10-12, America/Santiago)

Consultas de solo lectura contra Supabase con ambas sesiones: auth y roles RPC correctos; cada cuenta leyo su perfil propio. El rol GRADUADO no obtuvo filas al consultar por el ID del perfil SUPER_ADMIN de prueba; SUPER_ADMIN obtuvo una fila al consultar el perfil GRADUADO. Evidencia sanitizada: `verificacion_aislamiento_perfil_20261012.json`. No se hicieron escrituras.

CP-01 sigue BLOQUEADO como flujo completo (Flutter no ejecutable); CP-05 sigue BLOQUEADO (sin alta de encuesta). Los conteos de estado por caso siguen 0 aprobados, 0 fallidos, 31 bloqueados, 2 no ejecutados; las comprobaciones parciales no elevan un caso completo a APROBADO.

Comandos adicionales: `Invoke-WebRequest` GET al frontend: HTTP 200; PowerShell `Invoke-RestMethod` para auth, RPC de rol y SELECT RLS de perfiles; Edge headless en `/admin/dashboard` interrumpido por no finalizar (sin captura). `flutter test` y `flutter --version` continuaron sin salida. No se generaron PNG.
