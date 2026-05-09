SELECT bulk_update_request_versions.id,
       bulk_update_request_versions.updater_id,
       bulk_update_request_versions.script,
       bulk_update_request_versions.script_changed,
       bulk_update_request_versions.status,
       bulk_update_request_versions.status_changed,
       bulk_update_request_versions.title,
       bulk_update_request_versions.title_changed,
       bulk_update_request_versions.version,
       bulk_update_request_versions.title,
       bulk_update_request_versions.created_at,
       bulk_update_request_versions.updated_at
FROM public.bulk_update_request_versions ORDER BY bulk_update_request_versions.id ASC
