-- Estadísticas agregadas del dashboard. Ejecutar con el editor SQL de Supabase.
-- SECURITY INVOKER conserva RLS y usa los permisos administrativos ya definidos.
create or replace function public.obtener_estadisticas_dashboard_admin()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  resultado jsonb;
begin
  if public.obtener_rol_usuario() not in ('SUPER_ADMIN', 'ADMINISTRADOR') then
    raise exception 'No tienes permisos para consultar las estadísticas administrativas';
  end if;

  select jsonb_build_object(
    'total_graduados', (select count(*) from public.graduados),
    'graduados_completaron', (
      select count(distinct re.id_graduado)
      from public.respuestas_encuesta re
      where re.estado = 'COMPLETADA'
    ),
    'graduados_pendientes', (
      select greatest(count(distinct g.id) - count(distinct re.id_graduado), 0)
      from public.graduados g
      left join public.respuestas_encuesta re
        on re.id_graduado = g.id and re.estado = 'COMPLETADA'
    ),
    'por_encuesta', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'titulo', x.titulo, 'completadas', x.completadas) order by x.titulo)
      from (
        select e.id, e.titulo, count(re.id) as completadas
        from public.encuestas e
        left join public.respuestas_encuesta re on re.id_encuesta = e.id and re.estado = 'COMPLETADA'
        group by e.id, e.titulo
      ) x
    ), '[]'::jsonb),
    'por_anio_egreso', coalesce((
      select jsonb_agg(jsonb_build_object('etiqueta', x.etiqueta, 'cantidad', x.cantidad) order by x.etiqueta)
      from (select g.año_egreso::text as etiqueta, count(*) as cantidad from public.graduados g where g.año_egreso is not null group by g.año_egreso) x
    ), '[]'::jsonb),
    'por_departamento', coalesce((
      select jsonb_agg(jsonb_build_object('etiqueta', x.etiqueta, 'cantidad', x.cantidad) order by x.etiqueta)
      from (select g.departamento as etiqueta, count(*) as cantidad from public.graduados g where nullif(trim(g.departamento), '') is not null group by g.departamento) x
    ), '[]'::jsonb),
    'distribucion_respuestas', coalesce((
      select jsonb_agg(jsonb_build_object('etiqueta', x.etiqueta, 'cantidad', x.cantidad) order by x.cantidad desc)
      from (
        select left(p.pregunta, 40) || ' · ' || op.opcion as etiqueta, count(*) as cantidad
        from public.respuestas_encuesta re
        join public.respuestas r on r.id_respuesta_encuesta = re.id
        join public.preguntas p on p.id = r.id_pregunta
        join public.opciones_pregunta op on op.id = r.id_opcion
        where re.estado = 'COMPLETADA'
        group by p.id, p.pregunta, op.id, op.opcion
        union all
        select left(p.pregunta, 40) || ' · ' || op.opcion as etiqueta, count(*) as cantidad
        from public.respuestas_encuesta re
        join public.respuestas r on r.id_respuesta_encuesta = re.id
        join public.preguntas p on p.id = r.id_pregunta
        join public.respuestas_opciones ro on ro.id_respuesta = r.id
        join public.opciones_pregunta op on op.id = ro.id_opcion
        where re.estado = 'COMPLETADA'
        group by p.id, p.pregunta, op.id, op.opcion
      ) x
    ), '[]'::jsonb)
  ) into resultado;

  return resultado;
end;
$$;

revoke all on function public.obtener_estadisticas_dashboard_admin() from public, anon;
grant execute on function public.obtener_estadisticas_dashboard_admin() to authenticated;

--datos para la base de datos:

-- =========================================================
-- SEGURIDAD: CAMBIO DE ROLES EXCLUSIVO PARA SUPER_ADMIN
-- =========================================================

CREATE OR REPLACE FUNCTION public.administrar_rol_usuario(
    p_usuario_id uuid,
    p_rol_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol_actual text;
    v_nuevo_rol text;
    v_superadmins bigint;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    SELECT r.nombre
    INTO v_rol_actual
    FROM public.perfiles p
    JOIN public.roles r ON r.id = p.id_rol
    WHERE p.id = auth.uid();

    IF v_rol_actual IS DISTINCT FROM 'SUPER_ADMIN' THEN
        RAISE EXCEPTION 'Solo SUPER_ADMIN puede gestionar roles.';
    END IF;

    IF p_usuario_id = auth.uid() THEN
        RAISE EXCEPTION 'No puedes cambiar tu propio rol.';
    END IF;

    SELECT nombre
    INTO v_nuevo_rol
    FROM public.roles
    WHERE id = p_rol_id;

    IF v_nuevo_rol IS NULL THEN
        RAISE EXCEPTION 'El rol seleccionado no existe.';
    END IF;

    PERFORM 1
    FROM public.perfiles
    WHERE id = p_usuario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario no existe.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.perfiles
        WHERE id = p_usuario_id
          AND id_rol = p_rol_id
    ) THEN
        RETURN;
    END IF;

    SELECT count(*)
    INTO v_superadmins
    FROM public.perfiles p
    JOIN public.roles r ON r.id = p.id_rol
    WHERE r.nombre = 'SUPER_ADMIN';

    IF EXISTS (
        SELECT 1
        FROM public.perfiles p
        JOIN public.roles r ON r.id = p.id_rol
        WHERE p.id = p_usuario_id
          AND r.nombre = 'SUPER_ADMIN'
    ) AND v_superadmins <= 1 THEN
        RAISE EXCEPTION 'Debe existir al menos un SUPER_ADMIN.';
    END IF;

    UPDATE public.perfiles
    SET id_rol = p_rol_id
    WHERE id = p_usuario_id;

END;
$$;

REVOKE ALL ON FUNCTION
    public.administrar_rol_usuario(uuid, bigint)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.administrar_rol_usuario(uuid, bigint)
TO authenticated;


-- =========================================================
-- ÍNDICES PARA LISTADOS Y AUDITORÍA
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_perfiles_nombre
ON public.perfiles (apellidos, nombres);

CREATE INDEX IF NOT EXISTS idx_auditoria_tabla_fecha
ON public.auditoria (tabla_afectada, fecha DESC);

CREATE INDEX IF NOT EXISTS idx_auditoria_accion_fecha
ON public.auditoria (accion, fecha DESC);


-- =========================================================
-- AUDITORÍA: AGREGAR TABLAS QUE FALTABAN
-- =========================================================

DROP TRIGGER IF EXISTS trg_auditoria_respuestas_encuesta
ON public.respuestas_encuesta;

CREATE TRIGGER trg_auditoria_respuestas_encuesta
AFTER INSERT OR UPDATE OR DELETE
ON public.respuestas_encuesta
FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


DROP TRIGGER IF EXISTS trg_auditoria_respuestas
ON public.respuestas;

CREATE TRIGGER trg_auditoria_respuestas
AFTER INSERT OR UPDATE OR DELETE
ON public.respuestas
FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


DROP TRIGGER IF EXISTS trg_auditoria_respuestas_opciones
ON public.respuestas_opciones;

CREATE TRIGGER trg_auditoria_respuestas_opciones
AFTER INSERT OR UPDATE OR DELETE
ON public.respuestas_opciones
FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


DROP TRIGGER IF EXISTS trg_auditoria_opciones_pregunta
ON public.opciones_pregunta;

CREATE TRIGGER trg_auditoria_opciones_pregunta
AFTER INSERT OR UPDATE OR DELETE
ON public.opciones_pregunta
FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();
