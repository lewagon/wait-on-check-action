FROM ruby:3.2.7-slim-bullseye

RUN apt-get update && apt-get install -y build-essential
RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY app app
COPY entrypoint.rb .

ENTRYPOINT ["/entrypoint.rb"]
