CREATE OR REPLACE FUNCTION admin_get_vacancies()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', extensions
AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'ok', true,
      'data', COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', id,
            'position', position,
            'department', department,
            'quota', quota,
            'qualifications', qualifications,
            'status', status
          ) ORDER BY created_at DESC
        ),
        '[]'::jsonb
      )
    )
    FROM vacancies
  );
END;
$$;
