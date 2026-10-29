# Resultados SEG-01 a SEG-18

| ID | Control / nivel | Resultado y evidencia |
|---|---|---|
| SEG-01 | Rutas privadas; UI/Auth | BLOQUEADO: requiere navegación real anónima. |
| SEG-02 | Login; Auth | BLOQUEADO: requiere backend/cuenta temporal. |
| SEG-03 | Logout; Auth/UI | BLOQUEADO: requiere sesión y navegación atrás. |
| SEG-04 | Roles; RPC/RLS/API | BLOQUEADO dinámicamente. Inspección de `AuthGate` evidencia comprobación de rol en ruta web. |
| SEG-05 | Aislamiento; RLS | BLOQUEADO dinámicamente. SQL declara políticas de dueño en perfiles, graduados, respuestas y recomendaciones. |
| SEG-06 | SELECT/INSERT/UPDATE/DELETE; SQL | REVISIÓN ESTÁTICA: RLS habilitado y policies declaradas. Sin PostgreSQL disponible para verificar efectividad. |
| SEG-07 | Escalamiento; RLS | RIESGO ESTÁTICO por validar: update propio en `perfiles` filtra por id, sin restricción de columna visible en policy. Comprobar si grants permiten cambiar `id_rol`; no es vulnerabilidad confirmada. |
| SEG-08 | IDs; RLS/trigger | BLOQUEADO dinámicamente; trigger valida asociación respuesta/pregunta y encuesta. |
| SEG-09 | Entradas; UI/DB | BLOQUEADO dinámicamente; SQL define checks para fechas, tipo y orden. |
| SEG-10 | Integridad encuesta; DB | BLOQUEADO dinámicamente; existen FK, unique, checks y triggers de consistencia. |
| SEG-11 | Recomendaciones; RLS | BLOQUEADO dinámicamente; SQL limita insert al dueño y update a roles admin. |
| SEG-12 | Secretos; estático | PENDIENTE de escaneo automatizado rastreado y revisión; no se muestran secretos. |
| SEG-13 | Errores; UI/API | BLOQUEADO dinámicamente; login presenta mensaje de AuthException. |
| SEG-14 | Acceso directo; Supabase | BLOQUEADO: faltan URL, clave pública y cuentas. |
| SEG-15 | Integridad; DB | REVISIÓN ESTÁTICA: claves, unique y checks declarados; no ejecutados en DB. |
| SEG-16 | Inyección; estático/dinámico | PENDIENTE: validar entradas inocuas; cliente usa API tipada de Supabase. |
| SEG-17 | Exposición; API/RLS | BLOQUEADO dinámicamente. |
| SEG-18 | CRUD por rol; RLS | BLOQUEADO dinámicamente. |

No se usaron datos reales ni se generaron capturas PNG. No hay vulnerabilidades confirmadas sin verificación dinámica. SEG-07 amerita prioridad: limitar cambio de `id_rol` en DB (trigger, privilegios por columna o RPC restringida) y comprobarlo con sesión GRADUADO en instancia aislada.
