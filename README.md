# Start the indexer with reference to Supabase's .env file

docker compose -f docker-compose.voi.yml --env-file ../supabase/docker/.env up -d

# To stop the indexer

docker compose -f docker-compose.voi.yml --env-file ../supabase/docker/.env down

# To view logs

docker compose -f docker-compose.voi.yml --env-file ../supabase/docker/.env logs -f

docker exec -it voi-follower-node /node/bin/goal -d /algod/data node status
