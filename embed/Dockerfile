FROM node:23.1.0-slim

WORKDIR /opt/netapp/ai

RUN apt-get update
RUN apt-get install -y cifs-utils --no-install-recommends

ADD package.json ./
ADD package-lock.json ./
ADD src/ ./
ADD tsconfig.json ./
RUN npm i --force
RUN npm run build

ADD migrations ./migrations
ADD .env ./

CMD ["node", "--import", "./dist/register-hooks.js", "./dist/index.js"]