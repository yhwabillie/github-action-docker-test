FROM node:18-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json yarn.lock .yarnrc.yml ./ 
RUN corepack enable && corepack prepare yarn@4.3.1 && yarn
# RUN rm node_modules

FROM base AS builder
WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/.yarn ./.yarn
RUN yarn build

FROM builder AS runner
WORKDIR /app
COPY --from=builder /app/public ./.next/standalone/public
COPY --from=builder /app/.next/static ./.next/standalone/.next/static

# 컨테이너의 수신 대기 포트를 3000으로 설정
EXPOSE 3000
ENV PORT 3000

# # # node로 애플리케이션 실행
CMD HOSTNAME="0.0.0.0" node .next/standalone/server.js
