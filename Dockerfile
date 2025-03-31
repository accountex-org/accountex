# define arguments
ARG EX_VSN=1.18.3
ARG OTP_VSN=27.3.1
ARG UBT_VSN=focal-20241011
ARG BUILDER_IMG="hexpm/elixir:${EX_VSN}-erlang-${OTP_VSN}-ubuntu-${UBT_VSN}"
ARG RUNNER_IMG="ubuntu:${UBT_VSN}"

#################
## build stage ##
#################
FROM ${BUILDER_IMG} AS builder

# prepare build directory
WORKDIR /app

# install hex and rebar 
RUN mix local.hex --force && mix local.rebar --force

# set build environment
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# copy project config
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/

# compile application
RUN mix deps.compile

# copy priv, lib and assets 
COPY priv priv
COPY lib lib
COPY assets assets

# compile assets
RUN mix assets.deploy

# compile the release
RUN mix compile

# copy changes to config
COPY config/runtime.exs config/

# copy and compile the release
COPY rel rel
RUN mix release

##################
## runner stage ##
##################

FROM ${RUNNER_IMG} AS runner

# install runtime libraries
RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR "/app"
RUN chown nobody /app

# set the runner ENV
ENV MIX_ENV="prod"

# only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/accountex ./
USER nobody
CMD ["/app/bin/server"]







