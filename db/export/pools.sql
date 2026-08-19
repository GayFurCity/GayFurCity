SELECT pools.id,
       pools.name,
       pools.creator_id,
       pools.description,
       pools.is_ongoing,
       pools.post_ids,
       pools.created_at,
       pools.updated_at,
       pools.artist_names
FROM public.pools ORDER BY pools.id ASC
