FROM rockylinux:9.3-minimal

WORKDIR /opt/netapp/ai

RUN microdnf install xz -y
RUN microdnf install cifs-utils -y
RUN microdnf install tar -y
RUN microdnf install make -y
RUN microdnf install gcc -y
RUN microdnf install gcc-c++ -y

ENV NODE_VERSION 23.1.0

RUN curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s $NODE_VERSION

ADD package.json ./
ADD package-lock.json ./
ADD src/ ./
ADD tsconfig.json ./
RUN npm i --force
RUN npm run build

ADD migrations ./migrations
ADD .env ./

CMD ["node", "--import", "./dist/register-hooks.js", "./dist/index.js"]