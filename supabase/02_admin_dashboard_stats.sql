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
