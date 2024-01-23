# FROMFREEZE docker.io/library/ruby:3.1.2
#===============================================================================
FROM docker.io/library/ruby@sha256:7681a3d37560dbe8ff7d0a38f3ce35971595426f0fe2f5709352d7f7a5679255 AS dev

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        shellcheck \
        && \
    rm -rf /var/lib/apt/lists/*

RUN useradd x -m && \
    mkdir /home/x/r && \
    chown -R x:x /home/x
#-------------------------------------------------------------------------------
USER x

WORKDIR /home/x/r

COPY --chown=x:x Gemfile Gemfile.lock *.gemspec ./

COPY --chown=x:x lib/register_transformer_psc/version.rb lib/register_transformer_psc/

RUN bundle install

COPY --chown=x:x . .

ENV PATH=/home/x/r/bin:$PATH

ENTRYPOINT ["entrypoint-dev"]
