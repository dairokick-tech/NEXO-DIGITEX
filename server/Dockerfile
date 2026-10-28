FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY tsconfig.json ./
COPY src ./src
COPY sql ./sql
RUN npm install --no-save typescript
RUN npx tsc -p tsconfig.json
EXPOSE 8080
CMD ["node", "dist/index.js"]
