FROM node:18-alpine

WORKDIR /app

# Cache-busting argument to force rebuild when needed
ARG CACHEBUST=1

# Copy backend package files
COPY backend/package*.json ./

# Install dependencies
RUN npm install

# Copy backend source code
COPY backend/ .

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 3000

# Start command (uses 4GB memory limit)
CMD ["npm", "start"]
