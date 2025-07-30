# Use official Node.js image
FROM node:22-alpine

# Set environment variables
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application code
COPY . .

# Build the Strapi admin panel
RUN npm run build

# Expose the default Strapi port
EXPOSE 1337

# Start the Strapi app
CMD ["npm", "run", "start"] 