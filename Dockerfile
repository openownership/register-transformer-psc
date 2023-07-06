FROM ruby:3.1.2-bullseye

WORKDIR /app

COPY Gemfile Gemfile.lock register_transformer_psc.gemspec /app/
COPY lib/register_transformer_psc/version.rb /app/lib/register_transformer_psc/

# Download public key for github.com
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

RUN --mount=type=ssh bundle install

COPY . /app/

CMD ["bundle", "exec", "rspec"]
