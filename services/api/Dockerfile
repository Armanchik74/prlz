FROM node:22.14-alpine AS build
WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci --ignore-scripts && npm cache clean --force
COPY src ./src
RUN npm run build

FROM node:22.14-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S app && adduser -S -G app -u 10001 app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --from=build /app/dist ./dist
USER 10001
EXPOSE 3000
CMD ["node", "dist/src/server.js"]
