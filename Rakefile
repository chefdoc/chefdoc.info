require_relative 'init'

namespace :server do
  desc 'Start the server'
  task :start do
    mkdir_p 'tmp/pids'
    mkdir_p 'log'
    bundle = 'bundle exec ' unless ENV['DOCKERIZED']
    sh "#{bundle}puma -C config/puma.rb"
  end

  desc 'Restart the server'
  task restart: 'cache:clean_index' do
    sh 'kill -9 `cat tmp/pids/server.pid`'
  end

  desc 'Shut down the server'
  task :stop do
    sh 'kill -9 `cat tmp/pids/server.pid`'
  end
end

namespace :cache do
  desc 'Clean index cache pages (github, gems, featured)'
  task :clean_index do
    puts '>> Removing index cache pages'
    load('scripts/clean_index_cache.rb')
  end

  desc 'Clean HTML cache of cookbooks'
  task :clean_disk_html do
    puts '>> Removing HTML cache pages'
    system 'find public/cookbooks -atime +7 -exec rm -vrf {} \;'
  end

  desc 'Clean repository cache of cookbooks'
  task :clean_disk_repos do
    puts '>> Removing gem repositories'
    system 'rm -rf repos/cookbooks/*'
  end
end

DOCKER_IMAGE = 'chefdoc/chefdoc.info:latest'.freeze

namespace :docker do
  desc 'Build docker image'
  task :build do
    sh "docker build --rm=true --force-rm -t #{DOCKER_IMAGE} ."
  end

  desc 'Push docker image'
  task :push do
    sh "docker push #{DOCKER_IMAGE}"
  end

  desc 'Start docker image'
  task start: [:start_redis] do
    wd = ENV['WORKDIR'] || File.expand_path('data', File.dirname(__FILE__))
    options = ['-d',
               "--volume=#{wd}:/data",
               "--env 'REDIS_HOST=redis.db'",
               '--link chefdoc-redis:redis.db',
               '--name chefdoc',
               '-p 8080:8080'
             ]
    sh "rm -rf #{wd} && mkdir -p #{wd}"
    sh "docker run #{options.join(' ')} #{DOCKER_IMAGE}"
  end

  task :shell do
    pid = `docker ps -q`.strip.split(/\r?\n/).first
    sh "docker exec -it #{pid} /bin/bash"
  end

  task :git_pull do
    sh 'git pull origin master'
  end

  desc 'Pull latest image'
  task :pull do
    sh "docker pull #{DOCKER_IMAGE}"
  end

  desc 'Stops docker image'
  task stop: [:stop_redis] do
    sh 'docker rm -f chefdoc' do |ok, _res|
      puts 'Redis container not running' unless ok
    end
  end

  desc 'Restart docker image'
  task restart: [:stop, :start]

  desc 'Pull and update'
  task upgrade: [:git_pull, :pull, :restart]

  desc 'Start redis docker container'
  task :start_redis do
    sh 'docker ps -a -q --filter=name=chefdoc-redis | wc -l | grep 1' do |ok, _res|
      sh 'docker run --name chefdoc-redis -p 6379:6379 -d redis:3-alpine' unless ok
    end
  end

  desc 'Remove redis container cleaning the database cache'
  task :stop_redis do
    sh 'docker rm -f chefdoc-redis' do |ok, _res|
      puts 'Redis container not running' unless ok
    end
  end

  desc 'Restart redis (remove container and start again)'
  task restart_redis: [:stop_redis, :start_redis]
end
