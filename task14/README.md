# Unleash - Feature Flag Management Platform

## What is Unleash?

Unleash is an open-source feature flag and toggle management platform that enables teams to control feature rollouts, perform A/B testing, and manage feature flags across multiple environments. It provides a powerful API and user-friendly dashboard for managing feature flags in production applications.

### Key Concepts

#### Feature Flags (Toggles)
A feature flag is a boolean value that controls whether a feature is enabled or disabled. Features can be:
- **Enabled**: Feature is active and visible to users
- **Disabled**: Feature is inactive and hidden from users
- **Gradual Rollout**: Feature is enabled for a percentage of users

#### Strategies
Unleash supports various rollout strategies:
- **Default**: Simple on/off toggle
- **Gradual Rollout**: Percentage-based rollout
- **User Targeting**: Enable for specific users
- **Environment Targeting**: Enable for specific environments
- **Custom Strategies**: User-defined rollout logic

## What is Unleash Used For?

### 1. **Gradual Feature Rollouts**
- Safely deploy new features to a percentage of users
- Monitor performance and user feedback
- Roll back quickly if issues arise

### 2. **A/B Testing**
- Test different versions of features
- Compare user engagement and performance
- Make data-driven decisions about feature releases

### 3. **Kill Switch**
- Quickly disable problematic features in production
- Prevent widespread issues from affecting all users
- Maintain system stability during incidents

### 4. **Targeted Rollouts**
- Release features to specific user segments
- Enable features for beta testers or premium users
- Control feature access based on user attributes

### 5. **Environment Management**
- Manage different feature states across environments
- Test features in development and staging
- Promote features safely to production

## How to Set Up Unleash for Local React-Based Application

### Prerequisites
- Docker and Docker Compose
- Node.js (for React application)
- Git

### Step 1: Set Up Unleash Server

Create a `docker-compose.yml` file in your project:

```yaml
version: '3.8'

services:
  unleash:
    image: unleashorg/unleash-server:latest
    ports:
      - "4242:4242"
    environment:
      - DATABASE_URL=postgres://unleash:password@postgres:5432/unleash
      - ADMIN_AUTHENTICATION=none
    depends_on:
      - postgres
    networks:
      - unleash-network

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=unleash
      - POSTGRES_USER=unleash
      - POSTGRES_PASSWORD=password
    volumes:
      - unleash-data:/var/lib/postgresql/data
    networks:
      - unleash-network

volumes:
  unleash-data:

networks:
  unleash-network:
    driver: bridge
```

### Step 2: Start Unleash

```bash
# Start Unleash services
docker-compose up -d

# Verify services are running
docker-compose ps
```

### Step 3: Access Unleash Dashboard

Open your browser and navigate to:
- **Dashboard**: http://localhost:4242
- **API**: http://localhost:4242/api

### Step 4: Create Your First Feature Flag

1. Open the Unleash dashboard
2. Click "New feature toggle"
3. Fill in the details:
   - **Name**: `my-first-feature`
   - **Description**: `My first feature flag`
   - **Toggle type**: `Release`
4. Click "Create feature toggle"

### Step 5: Set Up React Application

#### Install Unleash React SDK

```bash
# In your React project directory
npm install @unleash/proxy-client-react
```

#### Configure Unleash Client

Create a configuration file (e.g., `src/unleash.js`):

```javascript
import { FlagProvider } from '@unleash/proxy-client-react';

const config = {
  url: 'http://localhost:4242/api/frontend',
  clientKey: 'your-client-key', // Get this from Unleash dashboard
  refreshInterval: 15,
  appName: 'my-react-app',
  environment: 'development'
};

export const UnleashProvider = ({ children }) => (
  <FlagProvider config={config}>
    {children}
  </FlagProvider>
);
```

#### Wrap Your App

Update your main App component:

```javascript
import React from 'react';
import { UnleashProvider } from './unleash';

function App() {
  return (
    <UnleashProvider>
      {/* Your app components */}
    </UnleashProvider>
  );
}

export default App;
```

#### Use Feature Flags in Components

```javascript
import React from 'react';
import { useFlag } from '@unleash/proxy-client-react';

const MyComponent = () => {
  const myFeature = useFlag('my-first-feature');

  return (
    <div>
      {myFeature ? (
        <div>New feature is enabled!</div>
      ) : (
        <div>New feature is disabled</div>
      )}
    </div>
  );
};

export default MyComponent;
```

### Step 6: Get Client Key from Unleash Dashboard

1. Go to the Unleash dashboard
2. Navigate to "API Access"
3. Create a new API token
4. Copy the client key and use it in your React app configuration

### Step 7: Test Your Setup

1. Start your React application
2. Toggle the feature flag in the Unleash dashboard
3. Observe real-time changes in your React app

## Environment Configuration

### Development Environment
```bash
# .env.development
REACT_APP_UNLEASH_URL=http://localhost:4242/api/frontend
REACT_APP_UNLEASH_CLIENT_KEY=your-dev-client-key
REACT_APP_UNLEASH_ENVIRONMENT=development
```

### Production Environment
```bash
# .env.production
REACT_APP_UNLEASH_URL=https://your-unleash-instance.com/api/frontend
REACT_APP_UNLEASH_CLIENT_KEY=your-prod-client-key
REACT_APP_UNLEASH_ENVIRONMENT=production
```

## Key Benefits of Using Unleash

1. **Risk Reduction**: Safe feature deployments with quick rollback capability
2. **Faster Development**: Decouple feature releases from code deployments
3. **Better Testing**: Test features with real users in production
4. **Improved User Experience**: Gradual rollouts and targeted features
5. **Operational Control**: Quick kill switches for problematic features

## Common Use Cases

- **Feature Rollouts**: Gradually release new features to users
- **A/B Testing**: Compare different versions of features
- **Kill Switches**: Quickly disable problematic features
- **User Targeting**: Enable features for specific user segments
- **Environment Management**: Control features across different environments

## Troubleshooting

### Common Issues

1. **Unleash not starting**: Check Docker logs with `docker-compose logs unleash`
2. **React app not connecting**: Verify the client key and URL configuration
3. **Feature flags not updating**: Check the refresh interval and network connectivity
4. **Dashboard not accessible**: Ensure port 4242 is not blocked by firewall

### Debug Commands

```bash
# Check Unleash status
curl http://localhost:4242/api/health

# View Unleash logs
docker-compose logs -f unleash

# Check if services are running
docker-compose ps
```

## Conclusion

Unleash provides a powerful and flexible solution for feature flag management in React applications. By following this setup guide, you can:

1. **Set up a local Unleash instance** for development
2. **Integrate feature flags** into your React application
3. **Test feature flag functionality** in a controlled environment
4. **Prepare for production deployment** with proper configuration

This setup enables teams to safely deploy features, perform A/B testing, and maintain operational control over their applications.

---

**Note**: This guide covers the basic setup for local development. For production deployments, consider additional security measures, monitoring solutions, and backup strategies. 