FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --quiet
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN adduser -D -u 1001 appuser && \
    chown -R appuser /usr/share/nginx/html && \
    chown -R appuser /var/cache/nginx && \
    chown -R appuser /var/log/nginx && \
    touch /var/run/nginx.pid && chown appuser /var/run/nginx.pid
USER appuser
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
