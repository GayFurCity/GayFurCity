server: rm -f /tmp/rails-server.pid && bin/rails server -p 9000 -b 0.0.0.0 --pid=/tmp/rails-server.pid
# server: PITCHFORK_LISTEN_ADDRESS=0.0.0.0:9000 PITCHFORK_WORKER_COUNT=2 bundle exec pitchfork -c config/pitchfork.rb
jobs: GOOD_JOB_PROCESS=1 GOOD_JOB_MAX_THREADS=10 GOOD_JOB_QUEUES="low,variants,iqdb,followers,tags,default,high" bundle exec good_job start
cron: run-parts /etc/periodic/daily && run-parts /etc/periodic/hourly && crond -f
webpack: WEBPACKER_DEV_SERVER_PORT=$EXPOSED_WEBPACKER_PORT WEBPACKER_DEV_SERVER_PUBLIC=http://localhost:$EXPOSED_WEBPACKER_PORT bin/webpack-dev-server
