FROM ruby:2.3
MAINTAINER Jörg Herzinger <joerg.herzinger+chefdoc@oiml.at>

# See https://github.com/docker-library/ruby/issues/45
ENV LANG C.UTF-8

# Bundle first to keep cache
ADD . /app
WORKDIR /app
RUN bundle install

EXPOSE 8080
ENV DOCKERIZED=1

# Put all data in this volume
ENV DATA_PATH=/data
VOLUME /data

CMD bundle exec rake server:start
