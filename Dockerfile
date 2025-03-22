FROM ruby:2.7.2-slim-buster

RUN apt-get update -y && apt-get -y install build-essential
RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY app app
COPY entrypoint.rb .

ENTRYPOINT ["/entrypoint.rb"]
