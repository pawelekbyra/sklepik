FROM ruby:3.4.4-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-client \
    libpq-dev \
    libyaml-dev \
    zlib1g-dev \
    libvips42 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy spree gems from this fork
COPY spree/ /workspace/spree/

# Clone spree-starter fresh into /workspace/server
# spree_dashboard is stripped from its Gemfile: upstream declares it with
# `path: SPREE_PATH/spree`, but this fork never had that engine — the admin
# UI is packages/dashboard, deployed separately to Vercel, not baked into
# this image. Without this, bundle install 404s looking for a gem that
# doesn't exist in this fork's spree/ tree.
RUN git clone --depth 1 https://github.com/spree/spree-starter.git /workspace/server \
    && echo "3.4.4" > /workspace/server/.ruby-version \
    && sed -i "/gem 'spree_dashboard'/d" /workspace/server/Gemfile

WORKDIR /workspace/server

# Set SPREE_PATH so bundler uses our fork's gems
ENV SPREE_PATH=/workspace
ENV BUNDLE_IGNORE_CONFIG=1
ENV SECRET_KEY_BASE_DUMMY=1

# Install gems from this fork (not RubyGems)
RUN bundle install

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
