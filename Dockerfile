FROM node:20-alpine AS base
RUN corepack enable && corepack prepare yarn@4.3.1

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json yarn.lock .yarnrc.yml ./ 
RUN yarn --frozen-lockfile 

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/.yarn ./.yarn
COPY . .
RUN yarn build

# git-actions runner와 소통하기위한 cache 스테이지
FROM node:20-alpine AS next-cache
COPY --from=builder --chown=nextjs:nodejs /app/.next/cache ./.next/cache

# runner에서 .next를 새로 만들어서 각 스테이지마다 만든것을 필요한것만 가져와서 재조립
# app > .public, app > .next, app > .next > 호스트쪽 standalone폴더 내부 파일들, .next > static
FROM node:20-alpine AS runner
WORKDIR /app

# .next 폴더에 대한 컨테이너 사용자 권한 설정 (root 접속X, 보안)
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

# 컨테이너의 수신 대기 포트를 3000으로 설정
EXPOSE 3000
ENV HOSTNAME "0.0.0.0"
CMD ["node", "server.js"]
