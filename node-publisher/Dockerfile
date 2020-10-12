FROM node:14.9-slim AS build
WORKDIR /app
ADD package.json .
RUN npm install

FROM node:14.9-slim
WORKDIR /app
COPY --from=build /app .
ADD . .
EXPOSE 3000
CMD ["npx", "nodemon", "publisher.js"]