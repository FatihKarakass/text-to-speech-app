# 🎤 Enterprise TTS Platform

Modern Ruby on Rails text-to-speech application with multiple AI providers, background processing, and cloud storage integration.

## ✨ Features

- **🤖 3 AI TTS Providers**: OpenAI, ElevenLabs, Resemble AI
- **⚡ Background Processing**: Sidekiq + Redis for async job processing
- **☁️ Cloud Storage**: AWS S3 integration with presigned URLs
- **🔄 Error Recovery**: Cancel/Retry functionality for failed jobs
- **🎨 Modern UI**: Bootstrap 5 with real-time status updates
- **🌍 Multi-language**: Turkish and English support
- **🛡️ Production Ready**: Error handling, monitoring, security

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3.9
- Rails 8.0.2
- Redis server
- API keys for TTS providers

### Installation

```bash
# Clone repository
git clone <repository-url>
cd text-to-speech

# Install dependencies
bundle install

# Setup database
bin/rails db:migrate

# Start Redis
brew services start redis

# Configure API keys (copy .env.example to .env)
export ELEVENLABS_API_KEY="your_elevenlabs_key"
export RESEMBLE_API_KEY="your_resemble_key"
export OPENAI_API_KEY="your_openai_key"

# Start services
bin/rails server
bundle exec sidekiq
```

### Usage

1. Open `http://localhost:3000`
2. Enter text in the form
3. Click "Ses Oluştur" (Generate Speech)
4. Download generated audio files

## 🔧 Configuration

### API Keys

Create `.env` file with your API keys:

```env
ELEVENLABS_API_KEY=sk_your_elevenlabs_key
RESEMBLE_API_KEY=your_resemble_key
OPENAI_API_KEY=sk-proj-your_openai_key

# Optional: AWS S3 for production
AWS_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
```

### Development Mode

- Uses mock S3 service (files stored in `tmp/mock_s3/`)
- Graceful fallback when API keys not configured
- Real-time debugging and logging

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Interface │────│  Rails App       │────│  Sidekiq Jobs   │
│   (Bootstrap)   │    │  (Controllers)   │    │  (Async TTS)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │                        │
                         ┌──────▼──────┐        ┌──────▼──────┐
                         │  Database   │        │  TTS APIs   │
                         │  (SQLite3)  │        │  (AI Providers) │
                         └─────────────┘        └─────────────┘
                                                        │
                                                ┌──────▼──────┐
                                                │  S3 Storage │
                                                │  (Audio Files) │
                                                └─────────────┘
```

## 📊 TTS Providers

| Provider | Quality | Speed | Cost | Languages |
|----------|---------|-------|------|-----------|
| **ElevenLabs** | ⭐⭐⭐⭐⭐ | Fast | $$ | 29+ |
| **OpenAI** | ⭐⭐⭐⭐ | Fast | $ | 50+ |
| **Resemble** | ⭐⭐⭐⭐ | Medium | $$$ | Custom |

## 🛠️ Tech Stack

- **Backend**: Ruby on Rails 8.0.2
- **Database**: SQLite3 (development), PostgreSQL (production)
- **Jobs**: Sidekiq + Redis
- **Frontend**: Bootstrap 5, Stimulus.js
- **Storage**: AWS S3 (production), Local files (development)
- **Deployment**: Docker, Kamal

## 📱 API Endpoints

- `GET /` - Main interface
- `POST /tts` - Create TTS request
- `GET /speech_requests/:id` - View request status
- `GET /speech_requests/:id/download/:provider` - Download audio
- `PATCH /speech_requests/:id/cancel` - Cancel request
- `PATCH /speech_requests/:id/retry` - Retry failed providers

## 🎯 Production Deployment

1. Set environment variables
2. Configure AWS S3 bucket
3. Deploy with Kamal: `kamal deploy`
4. Monitor with Sidekiq Web UI at `/sidekiq`

## 📄 License

MIT License - see LICENSE file for details.

---

**🚀 Built with ❤️ using Ruby on Rails**
