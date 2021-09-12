FROM ruby:2.7.2-slim-buster AS base

RUN apt-get update -yqq && apt-get -yqq --no-install-recommends install build-essential

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN gem install bundler
RUN bundle config set with 'development test'
RUN bundle install --jobs 20 --retry 5
COPY app /app

COPY entrypoint.rb /entrypoint.rb
FROM base AS test
CMD cd app && bundle exec rspec

FROM base AS release
ENTRYPOINT ["/entrypoint.rb"]
