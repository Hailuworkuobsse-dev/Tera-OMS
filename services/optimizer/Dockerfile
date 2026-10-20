FROM node:20-alpine
WORKDIR /app
RUN corepack enable
COPY package.json ./
RUN pnpm install --prod=false
COPY src ./src
CMD ["pnpm", "tsx", "src/main.ts"]
