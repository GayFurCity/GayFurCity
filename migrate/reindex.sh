#!/bin/bash

docker compose run --rm gayfurcity sh -c "/app/db/fixes/reindex_elasticsearch_posts.rb && /app/db/fixes/reindex_elasticsearch_post_versions.rb"
