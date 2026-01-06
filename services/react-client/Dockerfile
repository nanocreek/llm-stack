# Stage 1: Build React application
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production=false

# Copy source code
COPY public/ ./public/
COPY src/ ./src/
COPY vite.config.js ./

# Copy index.html to root (Vite expects it at project root)
COPY public/index.html ./index.html

# Build the React application
RUN npm run build

# Stage 2: Production nginx server
FROM nginx:alpine

# Copy nginx configuration
RUN echo 'server {\n\
    listen 3000;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html index.htm;\n\
    \n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    \n\
    location ~* ^.+\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {\n\
        expires 1y;\n\
        add_header Cache-Control "public, immutable";\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf

# Copy built application from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
