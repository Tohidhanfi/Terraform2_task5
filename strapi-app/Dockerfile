# Use official Node.js image with a more stable version
FROM node:18-alpine

# Set environment variables
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies with better error handling
RUN npm ci --only=production --no-audit --no-fund

# Copy the rest of the application code
COPY . .

# Build the Strapi admin panel
RUN npm run build

# Expose the default Strapi port
EXPOSE 1337

# Start the Strapi app
CMD ["npm", "run", "start"] 