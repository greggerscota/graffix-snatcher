FROM node:16.6.1-alpine3.13 AS builder

LABEL org.opencontainers.image.source="https://github.com/jef/streetmerchant"

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /build

COPY package.json package.json
COPY package-lock.json package-lock.json
COPY tsconfig.json tsconfig.json
RUN npm ci

COPY src/ src/
COPY test/ test/
RUN npm run compile
RUN npm prune --production

#FROM node:16.6.1-alpine3.13
FROM node:16.6.1-slim

#RUN apk add --no-cache chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
  DOCKER=true

# RUN addgroup -S appuser && adduser -S -g appuser appuser \
#   && mkdir -p /home/appuser/Downloads /app \
#   && chown -R appuser:appuser /home/appuser \
#   && chown -R appuser:appuser /app

# USER appuser

##############################################################################################################
# Install latest chrome dev package and fonts to support major charsets (Chinese, Japanese, Arabic, Hebrew, Thai and a few others)
# Note: this installs the necessary libs to make the bundled version of Chromium that Puppeteer
# installs, work.
RUN apt-get update \
    && apt-get install -y wget gnupg \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 \
      --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# If running Docker >= 1.13.0 use docker run's --init arg to reap zombie processes, otherwise
# uncomment the following lines to have `dumb-init` as PID 1
# ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_x86_64 /usr/local/bin/dumb-init
# RUN chmod +x /usr/local/bin/dumb-init
# ENTRYPOINT ["dumb-init", "--"]

# Uncomment to skip the chromium download when installing puppeteer. If you do,
# you'll need to launch puppeteer with:
#     browser.launch({executablePath: 'google-chrome-stable'})
# ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true

# Install puppeteer so it's available in the container.
#RUN npm i -g puppeteer \
    # Add user so we don't need --no-sandbox.
    # same layer as npm install to keep re-chowned files from using up several hundred MBs more space

##############################################################################################################

WORKDIR /app

COPY --from=builder /build/node_modules/ node_modules/
COPY --from=builder /build/build/ build/
COPY web/ web/
COPY package.json package.json

RUN npm i -g puppeteer \
    && groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /node_modules
  
# Run everything after as non-privileged user.
USER pptruser

ENTRYPOINT ["npm", "run"]
CMD ["start:production"]
