FROM ruby:2.6.6-slim-buster
COPY app /app

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN gem install bundler
RUN bundle config set with 'development test'
RUN bundle install --jobs 20 --retry 5

COPY entrypoint.rb /entrypoint.rb

ENTRYPOINT ["/entrypoint.rb"]
