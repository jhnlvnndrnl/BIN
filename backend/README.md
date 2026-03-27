# Backend Prerequisites

## Prerequisites

Before setting up the backend, ensure you have the following installed:

### Python
- **Version:** 3.9 or later
- **Installation:** Download from [python.org](https://www.python.org/downloads/)
- **Verify:** Run `python --version` or `python3 --version`

### pip
- **Included with Python:** pip comes bundled with Python 3.4+
- **Upgrade:** `python -m pip install --upgrade pip`

### Virtual Environment (Recommended)
- **venv:** Built-in Python module
- **Create:** `python -m venv venv`
- **Activate:**
  - Windows: `venv\Scripts\activate`
  - macOS/Linux: `source venv/bin/activate`

### Git
- **Installation:** [git-scm.com](https://git-scm.com/downloads)
- **Verify:** `git --version`

### Supabase CLI (Optional)
- **Installation:** `npm install -g supabase`
- **Verify:** `supabase --version`

### Railway CLI (Optional, for deployment)
- **Installation:** `npm install -g @railway/cli`
- **Verify:** `railway --version`

## Setup Instructions

1. Clone the repository
2. Navigate to the backend/fastapi directory
3. Create and activate virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. Set up environment variables (see .env.example)
6. Run the development server:
   ```bash
   uvicorn main:app --reload
   ```

## Environment Variables

Create a `.env` file in the backend/fastapi directory with the following variables:

```
SUPABASE_URL=your_supabase_url
FIREBASE_SERVICE_ACCOUNT=your_firebase_service_account
SUPABASE_SERVICE_KEY=your_supabase_service_key
```

## Database Setup

1. Ensure Supabase project is set up
2. Run migrations if any
3. Verify database connection

## Testing

Run tests with:
```bash
pytest
```

## API Documentation

Once running locally, visit `http://localhost:8000/docs` for interactive API documentation (Swagger UI).

For the deployed version, visit the Railway deployment URL + `/docs` for the live API documentation.

## Deployment

### Railway (Already Deployed)

The backend is currently deployed on Railway. The deployment is automatically updated on pushes to the main branch.

**Live API Endpoint:** https://bin-production-e68a.up.railway.app

**Deployment Details:**
- Connected to GitHub repository
- Environment variables configured in Railway dashboard
- Automatic deployments on main branch updates

### Local Development

For local development and testing:

1. Follow the setup instructions above
2. Run the local server: `uvicorn main:app --reload`
3. Access local API at `http://localhost:8000`
4. API docs at `http://localhost:8000/docs`