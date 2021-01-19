FROM ruby:2.6.6-slim-buster
COPY app /app

RUN apt-get update -yqq && apt-get -yqq --no-install-recommends install build-essential

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN gem install bundler
RUN bundle config set with 'development test'
RUN bundle install --jobs 20 --retry 5

COPY entrypoint.rb /entrypoint.rb

ENTRYPOINT ["/entrypoint.rb"]
