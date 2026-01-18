# Verification UI Service

Web-based dashboard for running and monitoring Railway deployment verification checks.

## Features

- 🎯 **Interactive Dashboard** - Beautiful web UI for all verification scripts
- ✅ **Checklist View** - See status of all verification checks at a glance
- ▶️ **One-Click Execution** - Run any verification script with a button click
- 🔄 **Re-run Capability** - Easily re-run failed or outdated checks
- 📊 **Real-time Output** - Watch script execution in real-time terminal
- 📈 **Statistics** - Track pass/fail rates and execution history
- 🔔 **Status Indicators** - Visual status badges (passed/failed/running)
- 📝 **Execution History** - Review past verification runs

## Quick Start

### Local Development

1. **Install dependencies:**
   ```bash
   cd services/verification-ui
   pip install -r requirements.txt
   ```

2. **Set environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run the application:**
   ```bash
   python app.py
   ```

4. **Open browser:**
   ```
   http://localhost:5000
   ```

### Railway Deployment

The service is configured to deploy automatically to Railway.

1. **Add service to Railway:**
   ```bash
   railway link
   railway up
   ```

2. **Set environment variables in Railway:**
   ```bash
   railway variables set SECRET_KEY=$(openssl rand -hex 32)
   ```

3. **Access your dashboard:**
   - Railway will provide a public URL
   - Example: `https://verification-ui-production.railway.app`

## Dashboard Overview

### Stats Cards
- **Total Checks** - Number of verification scripts available
- **Passed** - Currently passing checks
- **Failed** - Currently failing checks
- **Never Run** - Checks that haven't been executed yet

### Action Buttons
- **Run All Checks** - Execute all verification scripts sequentially
- **Run Critical Only** - Execute only critical security checks
- **Refresh Status** - Reload current status from server
- **Clear Output** - Clear the terminal output

### Verification Checks Panel

Each check displays:
- ✅ Status icon (passed/failed/running/never run)
- 📋 Check name and description
- ⚠️ Critical badge (if applicable)
- 🕐 Last run timestamp
- ⏱️ Execution duration
- ▶️ Run button

### Output Terminal
- Real-time streaming of script execution
- Color-coded output (errors in red, success in green)
- Auto-scroll to latest output
- Clear button to reset terminal

### Execution History
- Table of recent executions (last 10)
- Sortable by check name, status, time, duration
- Quick overview of verification trends

## Available Verification Checks

1. **Pre-Deployment Security** (CRITICAL)
   - Scans for exposed secrets and credentials
   - Checks .gitignore configuration
   - Validates Railway CLI setup

2. **Configuration Validation** (CRITICAL)
   - Validates environment variables for all services
   - Checks password strength requirements
   - Verifies internal networking configuration

3. **Service Health Checks** (CRITICAL)
   - Tests connectivity to all Railway services
   - Validates PostgreSQL, Redis, Qdrant, R2R, LiteLLM, OpenWebUI
   - Checks security headers and HTTPS

4. **Security Testing** (CRITICAL)
   - Comprehensive security tests per service
   - SSL/TLS enforcement
   - Authentication requirements
   - CORS and security headers

5. **Integration Testing**
   - End-to-end workflow tests
   - Service-to-service communication
   - Authentication flow validation

6. **Security Monitoring**
   - Monitors for security events
   - Error rate analysis
   - Certificate expiration checking

7. **Backup & Restore**
   - Database backup operations
   - Backup verification
   - Restore functionality

## Usage Examples

### Run All Critical Checks Before Deployment
1. Click "Run Critical Only" button
2. Watch real-time output in terminal
3. Review results - all critical checks should pass
4. If any fail, click individual check to re-run after fixes

### Monitor Deployment Health
1. Navigate to dashboard
2. Check stats cards for quick overview
3. Review individual check statuses
4. Re-run specific checks as needed

### Investigate Failures
1. Click on failed check's "Run" button
2. Review detailed output in terminal
3. Fix issues identified
4. Re-run check to verify fix

### Regular Security Audits
1. Click "Run All Checks"
2. Review execution history
3. Track trends over time
4. Address any new failures promptly

## API Endpoints

The service exposes a REST API for programmatic access:

### GET `/api/scripts`
Get list of all verification scripts with status
```json
[
  {
    "id": "pre-deployment",
    "name": "Pre-Deployment Security",
    "description": "Scans for exposed secrets...",
    "category": "security",
    "critical": true,
    "last_run": "2026-01-18T14:30:00",
    "last_status": "passed",
    "last_duration": 5.2,
    "exit_code": 0
  }
]
```

### GET `/api/history`
Get verification execution history
```bash
curl http://localhost:5000/api/history?limit=20
```

### GET `/api/history/<script_id>`
Get history for specific script
```bash
curl http://localhost:5000/api/history/pre-deployment
```

### GET `/api/stats`
Get overall statistics
```json
{
  "total_runs": 150,
  "total_passed": 140,
  "total_failed": 10,
  "current_status": {
    "passed": 6,
    "failed": 1,
    "never_run": 0,
    "total_checks": 7
  }
}
```

### GET `/health`
Health check endpoint
```bash
curl http://localhost:5000/health
```

## WebSocket Events

### Client → Server

**`run_script`** - Run a specific script
```javascript
socket.emit('run_script', {
  script_id: 'pre-deployment',
  args: ''  // optional command-line arguments
});
```

**`run_all`** - Run all scripts
```javascript
socket.emit('run_all', {
  skip_non_critical: false  // true to run only critical
});
```

### Server → Client

**`script_started`** - Script execution started
```javascript
socket.on('script_started', (data) => {
  // data: { script_id, name, timestamp }
});
```

**`script_output`** - Real-time output line
```javascript
socket.on('script_output', (data) => {
  // data: { script_id, line }
});
```

**`script_completed`** - Script execution finished
```javascript
socket.on('script_completed', (data) => {
  // data: { script_id, status, exit_code, duration, timestamp }
});
```

**`error`** - Error occurred
```javascript
socket.on('error', (data) => {
  // data: { script_id, message }
});
```

## Security Considerations

1. **Authentication** - Add authentication middleware for production
2. **HTTPS** - Always use HTTPS in production (Railway provides this)
3. **Secret Key** - Use strong random SECRET_KEY in production
4. **CORS** - Configure CORS appropriately for your domain
5. **Rate Limiting** - Consider adding rate limiting for API endpoints

### Adding Basic Authentication

Add to `app.py`:
```python
from functools import wraps
from flask import request, abort

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            abort(401)
        return f(*args, **kwargs)
    return decorated

def check_auth(username, password):
    # Implement your authentication logic
    return username == 'admin' and password == os.environ.get('ADMIN_PASSWORD')

@app.route('/')
@require_auth
def index():
    return render_template('index.html')
```

## Customization

### Adding New Verification Scripts

1. Add script to `scripts/verification/` directory
2. Update `VERIFICATION_SCRIPTS` in `app.py`:
   ```python
   VERIFICATION_SCRIPTS = {
       "my-new-check": {
           "name": "My New Check",
           "description": "Description of what it does",
           "script": "category/script-name.sh",
           "category": "security",
           "critical": True
       }
   }
   ```
3. Script will appear in dashboard automatically

### Customizing UI Colors/Styles

Edit the `<style>` section in `templates/index.html`:
```css
.stat-card {
    background: linear-gradient(135deg, #your-color-1 0%, #your-color-2 100%);
}
```

### Adding Alerting

Modify WebSocket handlers to send alerts:
```python
@socketio.on('script_completed')
def handle_completion(data):
    if data['status'] == 'failed' and data['critical']:
        send_slack_alert(f"Critical check failed: {data['name']}")
```

## Troubleshooting

### Scripts Not Running
- Ensure scripts are executable: `chmod +x scripts/verification/**/*.sh`
- Check Railway CLI is installed: `railway --version`
- Verify script paths in `VERIFICATION_SCRIPTS` configuration

### WebSocket Connection Issues
- Check firewall allows WebSocket connections
- Verify CORS settings in `app.py`
- Check browser console for errors

### Output Not Streaming
- Ensure eventlet worker is being used: `gunicorn --worker-class eventlet`
- Check WebSocket connection is established
- Verify no proxy blocking WebSocket upgrade

### Railway CLI Not Authenticated
- Set RAILWAY_TOKEN environment variable
- Or run: `railway login` in container

## Development

### Project Structure
```
services/verification-ui/
├── app.py                 # Flask application
├── templates/
│   └── index.html        # Dashboard UI
├── requirements.txt      # Python dependencies
├── Dockerfile            # Container configuration
├── railway.toml          # Railway deployment config
├── .env.example          # Environment variables template
└── README.md             # This file
```

### Running Tests
```bash
# Install dev dependencies
pip install pytest pytest-flask pytest-socketio

# Run tests
pytest
```

### Contributing
1. Fork the repository
2. Create feature branch
3. Make changes
4. Test locally
5. Submit pull request

## License

This verification UI is part of the LLM Stack project.
