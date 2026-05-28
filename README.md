# CareConnect Backend API

This is the Ruby on Rails 8 API that powers the CareConnect Hospital Management System.

##  Prerequisites
- Ruby 3.2.0+
- PostgreSQL 14+
- Bundler

##  Configuration

### 1. Environment Variables
Create a `.env` file in this directory and add the following:
```env
DB_USERNAME=your_postgres_user
DB_PASSWORD=your_postgres_password
GEMINI_API_KEY=your_google_gemini_api_key
SECRET_KEY_BASE=your_rails_secret
```

### 2. Database Setup
```bash
bundle install
rails db:create
rails db:migrate
rails db:seed
```

##  Running the API
```bash
rails s -p 3001
```
The API will be available at `http://localhost:3001`.

##  Northflank Deployment

Deploy this repository as a Dockerfile service:

- Dockerfile path: `Dockerfile`
- Build context: repository root
- Health check path: `/up`

Required production environment variables:

```env
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=<generated secret>
DATABASE_URL=<Northflank PostgreSQL connection string>
FRONTEND_URL=https://<your-frontend-public-url>
```

Optional environment variables:

```env
GEMINI_API_KEY=<google gemini api key>
SMTP_USERNAME=<smtp username>
SMTP_PASSWORD=<smtp password>
MAIL_FROM=<sender email>
```

After deployment, verify `https://<your-backend-public-url>/api/v1/health`.

##  Testing
```bash
bundle exec rspec
```

##  AI Triage Engine
The core prioritization logic is located in `app/services/ai_prioritization_service.rb`. It uses a combination of rule-based analysis and the Gemini 1.5 Flash model to calculate patient priority scores (0-100).

