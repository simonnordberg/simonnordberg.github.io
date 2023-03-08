FROM ruby:3.2.1-alpine

RUN apk update && apk add --no-cache build-base git

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install

CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0", "--port", "4000"]

EXPOSE 4000
