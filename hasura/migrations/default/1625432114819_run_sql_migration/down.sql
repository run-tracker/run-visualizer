-- Could not auto-generate a down migration.
-- Please write an appropriate down migration for the SQL below:
-- CREATE OR REPLACE FUNCTION public.filter_runs(object jsonb DEFAULT NULL::jsonb, path text[] DEFAULT NULL::text[], pattern text DEFAULT '%'::text)
 RETURNS SETOF run
 LANGUAGE sql
 STABLE
AS $function$
    SELECT *
    FROM run
    WHERE ($1 IS NULL OR metadata @> object)
    AND   ($2 IS NULL OR metadata #>>path like pattern)
$function$;