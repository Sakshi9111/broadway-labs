# Stage 1: BUILD - install everything, run tests, create dist/
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: RUN - only production dependencies and the built output
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
RUN mkdir -p data && chown node:node data
USER node
EXPOSE 3000
CMD ["node", "dist/src/server.js"]
