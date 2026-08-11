-- ==========================================================================
-- BEAT 2026/27 — consultas para revisar y mantener las postulaciones
-- ==========================================================================
-- Proyecto: lpet-marketing (uudwwhlmiradgbhfgnjv)
-- Correr en: Supabase → SQL Editor
--
-- Van numeradas. Cada bloque es independiente: selecciona el que quieras
-- y dale Run. Empieza por la 1.
--
-- 10 ago 2026
-- ==========================================================================


-- ==========================================================================
-- 1. LIMPIEZA — hacer esto primero, antes de que Felipe entre a mirar
-- ==========================================================================
-- Hoy hay filas de prueba mezcladas con lo real. Mira qué se va a borrar
-- ANTES de borrarlo.

SELECT created_at, full_name, email, video_source
FROM public.beat_submissions_2026
WHERE email LIKE 'test+%'
   OR email IN ('t@t.co')
   OR full_name LIKE 'ZZZ TEST%'
   OR full_name LIKE 'TEST%'
ORDER BY created_at;

-- Si la lista de arriba son SOLO pruebas (nombres con TEST, correos test+),
-- entonces borra:

-- DELETE FROM public.beat_submissions_2026
-- WHERE email LIKE 'test+%'
--    OR email IN ('t@t.co')
--    OR full_name LIKE 'ZZZ TEST%'
--    OR full_name LIKE 'TEST%';


-- ==========================================================================
-- 2. EL PANEL — todas las postulaciones, legibles
-- ==========================================================================
-- Lo esencial de cada una, sin los campos técnicos.

SELECT
  to_char(created_at AT TIME ZONE 'America/Bogota', 'DD Mon HH24:MI') AS recibida,
  full_name        AS nombre,
  email            AS correo,
  coalesce(city || ', ', '') || country AS lugar,
  CASE category WHEN 'barista' THEN 'Barista'
                WHEN 'brewers_cup' THEN 'Brewers Cup'
                ELSE category END AS categoria,
  target_competition AS compite_en,
  national_registration AS participaciones,
  CASE video_source WHEN 'upload' THEN '📁 archivo subido'
                    WHEN 'link'   THEN '🔗 enlace'
                    ELSE '—' END AS video,
  status AS estado
FROM public.beat_submissions_2026
ORDER BY created_at DESC;


-- ==========================================================================
-- 3. LOS VIDEOS — cómo abrir cada uno
-- ==========================================================================
-- Los de enlace abren con un clic. Los subidos viven en un bucket privado,
-- así que la URL directa NO abre: hay que ir al panel de Storage. Esta
-- consulta arma ese enlace por ti.

SELECT
  full_name AS nombre,
  CASE
    WHEN video_source = 'link' THEN video_url
    ELSE 'https://supabase.com/dashboard/project/uudwwhlmiradgbhfgnjv/storage/buckets/beat-videos?path='
         || regexp_replace(video_url, '^.*/beat-videos/', '')
  END AS abrir_video,
  CASE video_source WHEN 'link' THEN 'clic directo'
                    ELSE 'abre el panel de Storage' END AS como
FROM public.beat_submissions_2026
WHERE video_url IS NOT NULL
ORDER BY created_at DESC;


-- ==========================================================================
-- 4. ELEGIBILIDAD — quiénes cumplen la regla de este año
-- ==========================================================================
-- BEAT 2026/27 pide al menos dos participaciones nacionales. El formulario
-- ahora guarda el número al principio del texto ("3 national appearances — …"),
-- así que se puede filtrar. Las postulaciones viejas, con texto libre,
-- quedan como NULL y hay que leerlas a mano.

SELECT
  full_name AS nombre,
  substring(national_registration from '^(\d+)')::int AS veces,
  national_registration AS detalle,
  sponsor_status AS quien_lo_financia,
  CASE
    WHEN substring(national_registration from '^(\d+)')::int >= 2 THEN '✓ cumple'
    WHEN substring(national_registration from '^(\d+)')::int IS NULL THEN '? revisar a mano'
    ELSE '✗ menos de dos'
  END AS elegible
FROM public.beat_submissions_2026
ORDER BY substring(national_registration from '^(\d+)')::int DESC NULLS LAST;


-- ==========================================================================
-- 5. UNA POSTULACIÓN COMPLETA — para leerla entera
-- ==========================================================================
-- Cambia el correo por el de quien quieras ver.

SELECT *
FROM public.beat_submissions_2026
WHERE email = 'pon-aqui-el-correo@ejemplo.com';


-- ==========================================================================
-- 6. QUÉ HAY EN EL BUCKET — y qué sobra
-- ==========================================================================
-- Los archivos subidos viven en storage.objects. Esta consulta los cruza con
-- las postulaciones y marca los huérfanos: archivos que se subieron pero cuya
-- postulación nunca se completó (pasaba antes de arreglar el error del CHECK).

SELECT
  o.name AS archivo,
  round((o.metadata->>'size')::numeric / 1048576, 1) AS mb,
  to_char(o.created_at AT TIME ZONE 'America/Bogota', 'DD Mon HH24:MI') AS subido,
  CASE WHEN s.id IS NULL THEN '⚠ huérfano — se puede borrar'
       ELSE 'de ' || s.full_name END AS pertenece_a
FROM storage.objects o
LEFT JOIN public.beat_submissions_2026 s
       ON s.video_url LIKE '%' || o.name
WHERE o.bucket_id = 'beat-videos'
ORDER BY o.created_at DESC;

-- Para borrar los huérfanos, una vez confirmados arriba:
-- DELETE FROM storage.objects o
-- WHERE o.bucket_id = 'beat-videos'
--   AND NOT EXISTS (SELECT 1 FROM public.beat_submissions_2026 s
--                   WHERE s.video_url LIKE '%' || o.name);


-- ==========================================================================
-- 7. RESUMEN — cómo va la convocatoria
-- ==========================================================================

SELECT
  count(*)                                              AS total,
  count(*) FILTER (WHERE category = 'barista')          AS baristas,
  count(*) FILTER (WHERE category = 'brewers_cup')      AS brewers,
  count(*) FILTER (WHERE video_source = 'upload')       AS con_archivo,
  count(*) FILTER (WHERE video_source = 'link')         AS con_enlace,
  count(DISTINCT country)                               AS paises,
  count(*) FILTER (WHERE created_at > now() - interval '7 days') AS esta_semana,
  count(*) FILTER (WHERE consent_content)               AS ceden_contenido
FROM public.beat_submissions_2026;


-- ==========================================================================
-- 8. OPCIONAL — dejar el panel guardado como vista
-- ==========================================================================
-- Si corres esto una vez, después basta con:  SELECT * FROM beat_panel;
-- Es más cómodo que volver a pegar la consulta 2 cada vez.

-- CREATE OR REPLACE VIEW public.beat_panel AS
-- SELECT
--   created_at,
--   full_name, email, coalesce(city || ', ', '') || country AS lugar,
--   category, target_competition,
--   substring(national_registration from '^(\d+)')::int AS veces_nacional,
--   national_registration, sponsor_status,
--   video_source,
--   CASE WHEN video_source = 'link' THEN video_url
--        ELSE 'https://supabase.com/dashboard/project/uudwwhlmiradgbhfgnjv/storage/buckets/beat-videos?path='
--             || regexp_replace(video_url, '^.*/beat-videos/', '') END AS abrir_video,
--   pitch_text, current_roastery, past_competitions,
--   instagram_handle, tiktok_handle,
--   consent_content, status
-- FROM public.beat_submissions_2026;

-- Ojo: la vista hereda el RLS de la tabla, así que sigue siendo visible
-- solo para los correos de administración. No abre nada al público.
