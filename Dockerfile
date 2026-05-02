# Use official Node image
FROM node:20

# Create app directory inside container
WORKDIR /app

# Copy package files first (for caching dependencies)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy rest of the application
COPY . .

# Expose API port
EXPOSE 3000

#and create a new file called Dockerfile.dev
# Start the app
CMD ["node", "app.js"]