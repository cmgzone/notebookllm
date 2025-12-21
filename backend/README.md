# Custom Backend for Notebook LLM

A Node.js/Express backend with JWT authentication and PostgreSQL database integration.

## Features

- ✅ Custom JWT authentication (no Firebase)
- ✅ PostgreSQL database via Neon
- ✅ RESTful API for notebooks and sources  
- ✅ User authentication and authorization
- ✅ TypeScript for type safety
- ✅ CORS enabled for Flutter app

## Setup

1. **Install Dependencies**
```bash
npm install
```

2. **Configure Environment**
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```

3. **Run Development Server**
```bash
npm run dev
```

4. **Build for Production**
```bash
npm run build
npm start
```

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Create new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user (requires auth)

### Notebooks
- `GET /api/notebooks` - Get all notebooks (requires auth)
- `GET /api/notebooks/:id` - Get single notebook (requires auth)
- `POST /api/notebooks` - Create notebook (requires auth)
- `PUT /api/notebooks/:id` - Update notebook (requires auth)
- `DELETE /api/notebooks/:id` - Delete notebook (requires auth)

### Sources
- `GET /api/sources/notebook/:notebookId` - Get all sources for a notebook (requires auth)
- `GET /api/sources/:id` - Get single source (requires auth)
- `POST /api/sources` - Create source (requires auth)
- `PUT /api/sources/:id` - Update source (requires auth)
- `DELETE /api/sources/:id` - Delete source (requires auth)

## Environment Variables

See `.env.example` for all required environment variables.

## Project Structure

```
backend/
├── src/
│   ├── config/       # Database configuration
│   ├── middleware/   # Auth middleware
│   ├── routes/       # API routes
│   ├── services/     # Business logic
│   ├── models/       # Type definitions
│   ├── utils/        # Helper functions
│   └── index.ts      # Application entry point
├── .env.example      # Environment template
├── package.json
└── tsconfig.json
```

## Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Language**: TypeScript
- **Database**: PostgreSQL (Neon)
- **Authentication**: JWT + bcryptjs
