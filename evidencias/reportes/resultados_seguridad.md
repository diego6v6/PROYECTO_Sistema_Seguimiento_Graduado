# Resultados de seguridad SEG-01 a SEG-18

**Fecha de inspección:** 2026-10-12. **Ejecución dinámica:** no completada. No hay URL/clave local de Supabase, dispositivo, ni cuentas configuradas en el entorno; las pruebas Dart de seguridad están explícitamente omitidas. No se imprimen secretos. Evidencia de revisión: `supabase/01_schema_y_rls.sql`, `lib/screens/control_acceso.dart` y los archivos bajo `test/security/`.

| ID / objetivo | Componente y nivel | Precondiciones y pasos | Esperado | Observado / estado | Evidencia | Severidad / recomendación |
|---|---|---|---|---|---|---|
| SEG-01 Rutas privadas | AuthGate/UI | Abrir rutas protegidas sin sesión | Solicitar autenticación | No ejecutado; BLOQUEADO | `test/security/seg_01_rutas_privadas_test.dart` | — |
| SEG-02 Credenciales inválidas | Supabase Auth | Login con clave incorrecta | Sin sesión y error | No ejecutado; BLOQUEADO | `test/security/seg_02_credenciales_invalidas_test.dart` | — |
| SEG-03 Cierre de sesión | Auth/UI | Login, logout, recarga/atrás | Sesión revocada | No ejecutado; BLOQUEADO | `test/security/seg_03_cierre_sesion_test.dart` | — |
| SEG-04 Separación de roles | RPC/RLS/API | Login graduado e invocar operación admin | Denegación backend | UI consulta rol en `AuthGate`; backend no verificado; BLOQUEADO | `lib/screens/control_acceso.dart`; test SEG-04 | — |
| SEG-05 Aislamiento | RLS | Dos usuarios; leer/actualizar perfil, respuestas y recomendaciones ajenos | Sin lectura ni escritura ajena | Políticas declaradas estáticamente; sin sesión real; BLOQUEADO | `supabase/01_schema_y_rls.sql`; test SEG-05 | — |
| SEG-06 Revisión RLS CRUD | PostgreSQL RLS | Por cada tabla probar SELECT/INSERT/UPDATE/DELETE por rol | Aplicar mínimo privilegio | Solo revisión estática; RLS habilitado en tablas y policies declaradas; BLOQUEADO dinámico | SQL, sección 25–36; test SEG-06 | — |
| SEG-07 Escalamiento de rol | RLS/DB | Como graduado, actualizar su `id_rol`; consultar después | Cambio denegado | No probado. La policy de UPDATE propio limita fila por `id`, sin restricción de columna aparente; BLOQUEADO | SQL, políticas de perfiles; test SEG-07 | Riesgo potencial, no confirmado. Restringir `id_rol` en DB (column grants/trigger/RPC) y verificar en DB aislada. |
| SEG-08 Manipulación de IDs | RLS/triggers | Cambiar IDs de perfil, encuesta, respuesta y recomendación | IDs no evaden autorización | No probado. Trigger valida relación respuesta/pregunta; BLOQUEADO | SQL, `validar_respuesta_pregunta`; test SEG-08 | — |
| SEG-09 Validación entradas | UI/DB | Vacíos, tipos erróneos, longitudes y límites | Rechazo validado | Checks SQL visibles; sin ejecución; BLOQUEADO | SQL; test SEG-09 | — |
| SEG-10 Integridad encuesta/respuesta | DB | IDs inexistentes, duplicados y asociaciones cruzadas | FK/unique/trigger rechazan | Declaraciones estáticas; sin DB; BLOQUEADO | SQL, constraints y triggers; test SEG-10 | — |
| SEG-11 Seguridad recomendaciones | RLS | Graduado cambia estado/admin o modifica ajena | Solo admin cambia estado; dueño crea | Policies estáticas restringen INSERT/UPDATE; no comprobado por sesión; BLOQUEADO | SQL, policies recomendaciones; test SEG-11 | — |
| SEG-12 Protección secretos | Repositorio | Escaneo seguro de archivos rastreados | Sin secretos privilegiados | Escaneo dedicado no ejecutado; NO EJECUTADO | Sin log de escaneo | Ejecutar escáner sin imprimir valores; redactar hallazgos. |
| SEG-13 Errores/mensajes | UI/API | Provocar errores de auth/backend e inspeccionar texto | Sin tokens/SQL/datos privados | No ejecutado; BLOQUEADO. Login presenta el mensaje de AuthException; revisar filtrado dinámicamente | `lib/screens/pantalla_inicio_sesion.dart`; test SEG-13 | — |
| SEG-14 Acceso directo Supabase | API/RLS | Consultas con sesiones reales de cada rol y clave pública | RLS deniega lo no autorizado | Sin endpoint/sesiones; BLOQUEADO | test SEG-14 | — |
| SEG-15 Integridad datos | PostgreSQL | FK, checks, duplicados, estados | DB rechaza inconsistencia | Solo esquema estático; BLOQUEADO dinámico | SQL constraints; test SEG-15 | — |
| SEG-16 Inyección | UI/API | Entradas inocuas tipo comillas/HTML en formularios | Datos tratados como valores | Revisión superficial: consultas usan query builder Supabase; inputs no ejecutados; BLOQUEADO | `lib/`; test SEG-16 | — |
| SEG-17 Exposición información | API/RLS | Inspeccionar payloads por rol | Solo campos autorizados | No ejecutado; BLOQUEADO | test SEG-17 | — |
| SEG-18 CRUD por operación | API/RLS | Probar lectura, inserción, actualización y borrado por rol | Cada operación autorizada explícitamente | Sin sesiones reales; BLOQUEADO | test SEG-18 | — |

**Vulnerabilidades confirmadas:** ninguna. **Riesgo potencial:** SEG-07, sujeto a comprobar privilegios efectivos y posibilidad real de actualizar la columna. No se ejecutaron operaciones destructivas y no hay capturas PNG reales.

## Addendum: ejecucion autentica y RLS (2026-10-12)

Se verificaron las cuentas y roles con sesiones reales. SELECT propio: 1 fila coincidente para ambos roles. El graduado consulto el perfil de la otra cuenta de prueba y obtuvo 0 filas; el administrador consulto el perfil graduado y obtuvo 1 fila. Se probo solo SELECT en `perfiles`; no se probaron dos graduados, respuestas/recomendaciones ni mutaciones. SEG-05, SEG-06 y SEG-14 siguen BLOQUEADOS como controles completos, con subcomprobacion de perfiles aprobada. Evidencia: `verificacion_aislamiento_perfil_20261012.json`.

El archivo `supabase_lectura_roles_20261012.json` es historico preliminar y contiene un conteo de respuesta vacia incorrecto por tratamiento PowerShell de arrays vacios; no usar ese conteo. La verificacion corregida normaliza arrays vacios y compara el ID en memoria.

No se confirmaron vulnerabilidades. SEG-07 sigue siendo un riesgo potencial estatico que requiere una prueba de escritura en una base aislada. La captura Edge headless de `/admin/dashboard` se intento pero no termino; no existe PNG.
