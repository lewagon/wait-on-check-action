FROM ruby:2.6.6-slim-buster
COPY app /app
COPY entrypoint.rb /entrypoint.rb
ENTRYPOINT ["/entrypoint.rb"]
