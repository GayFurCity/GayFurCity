server: rm /tmp/rails-server.pid && bin/rails server -p 9000 -b 0.0.0.0 --pid=/tmp/rails-server.pid
# server: PITCHFORK_LISTEN_ADDRESS=0.0.0.0:9000 PITCHFORK_WORKER_COUNT=2 bundle exec pitchfork -c config/pitchfork.rb
jobs: SIDEKIQ_CONCURRENCY=10 SIDEKIQ_QUEUES="low:1;variants:1;iqdb:1;followers:1;tags:2;default:3;high:5" bundle exec sidekiq
cron: run-parts /etc/periodic/daily && run-parts /etc/periodic/hourly && crond -f
webpack: WEBPACKER_DEV_SERVER_PORT=$EXPOSED_WEBPACKER_PORT WEBPACKER_DEV_SERVER_PUBLIC=http://localhost:$EXPOSED_WEBPACKER_PORT bin/webpack-dev-server
