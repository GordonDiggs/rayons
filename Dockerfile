FROM ruby:2.3.0
MAINTAINER Gordon Diggs <gordon@gordondiggs.com>

RUN apt-get update && \
    apt-get install -y build-essential nodejs npm

COPY Gemfile* /app/
RUN cd /app && \
    bundle install --without development:test --path vendor/bundle --binstubs vendor/bundle/bin -j4 --deployment

COPY package.json /app/package.json
COPY node_modules /app/node_modules
RUN cd /app && npm install

ENV RAILS_ENV production
ENV LANG C.UTF-8

WORKDIR /app

COPY . /app

RUN bundle exec rake assets:precompile --trace && \
    bundle exec rake assets:clean

RUN git rev-parse HEAD > /app/REVISION

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
