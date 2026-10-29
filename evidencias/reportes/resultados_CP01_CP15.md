# Resultados CP-01 a CP-15

Ejecución local: se invocó `flutter test test` y luego `flutter test test/unit --reporter expanded`; el proceso de Flutter quedó sin salida incluso con `flutter --version` y se interrumpió. No se obtuvo un resultado de pruebas verificable. No había credenciales concretas en el prompt recibido ni variables de prueba configuradas. Cada archivo de caso informa `BLOQUEADO` como prueba omitida hasta proporcionar un entorno aislado.

| ID | Caso | Estado | Bloqueo |
|---|---|---|---|
| CP-01 | Login graduado válido | BLOQUEADO | Cuenta/clave, Supabase y dispositivo; confirmar rol por RPC. |
| CP-02 | Contraseña incorrecta | BLOQUEADO | Cuenta y Supabase. |
| CP-03 | Perfil propio | BLOQUEADO | Sesión, perfil ficticio y persistencia. |
| CP-04 | Datos de otro graduado | BLOQUEADO | Dos cuentas ficticias y RLS dinámica. |
| CP-05 | Crear encuesta | BLOQUEADO | Sesión SUPER_ADMIN y DB. |
| CP-06 | Encuesta inválida | BLOQUEADO | Formulario y DB ejecutables. |
| CP-07 | Crear pregunta | BLOQUEADO | Encuesta de prueba y sesión admin. |
| CP-08 | Pregunta inválida | BLOQUEADO | Formulario y backend. |
| CP-09 | Completar encuesta | BLOQUEADO | Encuesta activa y sesión graduado. |
| CP-10 | Pregunta obligatoria omitida | BLOQUEADO | Encuesta activa y backend. |
| CP-11 | Operación admin por graduado | BLOQUEADO | Sesión real e invocación backend directa. |
| CP-12 | Consultar respuestas | BLOQUEADO | Datos ficticios y sesión admin. |
| CP-13 | Crear recomendación | BLOQUEADO | Sesión graduado y DB. |
| CP-14 | Cambiar estado recomendación | BLOQUEADO | Registro ficticio y sesión admin. |
| CP-15 | Acceso sin autenticar | BLOQUEADO | Requiere app configurada y comprobación dinámica. |

La prueba unitaria de `AppConfig` está creada, pero su ejecución quedó bloqueada por el cuelgue de Flutter CLI. Ningún CP se declara aprobado por inspección estática.

## Addendum de ejecucion real (2026-10-12, America/Santiago)

Se autenticaron ambas cuentas temporales contra el Supabase configurado localmente; `obtener_rol_usuario()` devolvio sus roles esperados. SELECT de perfil propio devolvio la fila esperada para cada sesion. Con la sesion GRADUADO, la consulta al perfil SUPER_ADMIN de prueba devolvio cero filas; con sesion SUPER_ADMIN, la consulta al perfil GRADUADO devolvio una fila. Comparacion de IDs efectuada en memoria; IDs/tokens/correos no se guardaron. No hubo escrituras.

Esto cubre comprobaciones parciales, no cambia el estado general de CP-01 (falta flujo Flutter) ni CP-05 (no se creo encuesta porque el destino no esta confirmado como aislado). Evidencia: `verificacion_aislamiento_perfil_20261012.json`. No usar `supabase_lectura_roles_20261012.json` como resultado final: conserva el primer conteo incorrecto de arreglo vacio, corregido en el registro posterior.
