FROM node:20-alpine

RUN apk add --no-cache bash git curl jq coreutils python3 py3-pip

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY index.mjs ./

ENV NODE_ENV=production

EXPOSE 7337

USER node

CMD ["node", "/app/index.mjs"]

