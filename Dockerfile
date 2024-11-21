FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Install dependencies including Corepack and ensure compatibility
RUN apk add --no-cache libc6-compat
RUN corepack enable
WORKDIR /app

# Get PNPM version from package.json
COPY package.json pnpm-lock.yaml ./
RUN corepack prepare pnpm@$(jq -r '.engines.pnpm' < package.json) --activate

# Install dependencies using pnpm
RUN pnpm i --frozen-lockfile --prefer-offline

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

# Enable Corepack in the builder stage as well
RUN corepack enable

# Copy dependencies and source code
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for the build
ENV NEXT_OUTPUT=standalone
ARG NEXT_PUBLIC_SALEOR_API_URL
ENV NEXT_PUBLIC_SALEOR_API_URL=${NEXT_PUBLIC_SALEOR_API_URL:-https://api.r1prostore.com}
ARG NEXT_PUBLIC_STOREFRONT_URL
ENV NEXT_PUBLIC_STOREFRONT_URL=${NEXT_PUBLIC_STOREFRONT_URL:-https://r1prostore.com}

# Run the build command
RUN pnpm build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

# Set user permissions
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Ensure the .next directory exists and set permissions
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copy the build from the builder stage
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

CMD ["node", "server.js"]
