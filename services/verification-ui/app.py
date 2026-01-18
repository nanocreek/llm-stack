from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import subprocess
import os
import json
from datetime import datetime
import threading
import queue
from pathlib import Path

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-prod')
socketio = SocketIO(app, cors_allowed_origins="*")

# Base directory
BASE_DIR = Path(__file__).parent.parent.parent
SCRIPTS_DIR = BASE_DIR / "scripts" / "verification"
HISTORY_FILE = BASE_DIR / "verification-history.json"

# Verification scripts configuration
VERIFICATION_SCRIPTS = {
    "pre-deployment": {
        "name": "Pre-Deployment Security",
        "description": "Scans for exposed secrets and credentials",
        "script": "pre-deployment/01-secrets-check.sh",
        "category": "security",
        "critical": True
    },
    "config-validation": {
        "name": "Configuration Validation",
        "description": "Validates environment variables and settings",
        "script": "config/01-env-validation.sh",
        "category": "config",
        "critical": True
    },
    "service-health": {
        "name": "Service Health Checks",
        "description": "Tests connectivity and health of all services",
        "script": "health/01-service-health.sh",
        "category": "health",
        "critical": True
    },
    "security-tests": {
        "name": "Security Testing",
        "description": "Comprehensive security tests for each service",
        "script": "security/01-service-security-tests.sh",
        "category": "security",
        "critical": True
    },
    "integration-tests": {
        "name": "Integration Testing",
        "description": "End-to-end workflow and service communication tests",
        "script": "integration/01-integration-tests.sh",
        "category": "integration",
        "critical": False
    },
    "monitoring": {
        "name": "Security Monitoring",
        "description": "Monitors for security events and anomalies",
        "script": "monitoring/01-continuous-monitoring.sh",
        "category": "monitoring",
        "critical": False
    },
    "backup": {
        "name": "Backup & Restore",
        "description": "Database backup operations",
        "script": "backup/01-backup-restore.sh",
        "category": "backup",
        "critical": False
    }
}

def load_history():
    """Load verification history from file"""
    if HISTORY_FILE.exists():
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    return []

def save_history(history):
    """Save verification history to file"""
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)

def get_latest_results():
    """Get latest results for each script"""
    history = load_history()
    latest = {}

    for entry in reversed(history):
        script_id = entry.get('script_id')
        if script_id and script_id not in latest:
            latest[script_id] = entry

    return latest

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/scripts')
def get_scripts():
    """Get list of all verification scripts with their status"""
    latest_results = get_latest_results()

    scripts = []
    for script_id, config in VERIFICATION_SCRIPTS.items():
        latest = latest_results.get(script_id, {})

        scripts.append({
            'id': script_id,
            'name': config['name'],
            'description': config['description'],
            'category': config['category'],
            'critical': config['critical'],
            'last_run': latest.get('timestamp'),
            'last_status': latest.get('status', 'never_run'),
            'last_duration': latest.get('duration'),
            'exit_code': latest.get('exit_code')
        })

    return jsonify(scripts)

@app.route('/api/history')
def get_history():
    """Get verification history"""
    limit = request.args.get('limit', 50, type=int)
    history = load_history()
    return jsonify(history[-limit:])

@app.route('/api/history/<script_id>')
def get_script_history(script_id):
    """Get history for a specific script"""
    limit = request.args.get('limit', 20, type=int)
    history = load_history()

    script_history = [
        entry for entry in history
        if entry.get('script_id') == script_id
    ]

    return jsonify(script_history[-limit:])

@socketio.on('run_script')
def handle_run_script(data):
    """Run a verification script and stream output"""
    script_id = data.get('script_id')
    args = data.get('args', '')

    if script_id not in VERIFICATION_SCRIPTS:
        emit('error', {'message': 'Invalid script ID'})
        return

    config = VERIFICATION_SCRIPTS[script_id]
    script_path = SCRIPTS_DIR / config['script']

    if not script_path.exists():
        emit('error', {'message': f'Script not found: {script_path}'})
        return

    # Notify start
    emit('script_started', {
        'script_id': script_id,
        'name': config['name'],
        'timestamp': datetime.now().isoformat()
    })

    start_time = datetime.now()
    output_lines = []

    try:
        # Run script
        cmd = [str(script_path)]
        if args:
            cmd.extend(args.split())

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=SCRIPTS_DIR
        )

        # Stream output
        for line in iter(process.stdout.readline, ''):
            if line:
                output_lines.append(line.rstrip())
                emit('script_output', {
                    'script_id': script_id,
                    'line': line.rstrip()
                })

        process.wait()
        exit_code = process.returncode

        # Calculate duration
        duration = (datetime.now() - start_time).total_seconds()

        # Determine status
        if exit_code == 0:
            status = 'passed'
        else:
            status = 'failed'

        # Save to history
        history_entry = {
            'script_id': script_id,
            'name': config['name'],
            'timestamp': start_time.isoformat(),
            'duration': duration,
            'status': status,
            'exit_code': exit_code,
            'output': '\n'.join(output_lines)
        }

        history = load_history()
        history.append(history_entry)
        save_history(history)

        # Notify completion
        emit('script_completed', {
            'script_id': script_id,
            'status': status,
            'exit_code': exit_code,
            'duration': duration,
            'timestamp': datetime.now().isoformat()
        })

    except Exception as e:
        emit('error', {
            'script_id': script_id,
            'message': str(e)
        })

@socketio.on('run_all')
def handle_run_all(data):
    """Run all verification scripts sequentially"""
    skip_non_critical = data.get('skip_non_critical', False)

    scripts_to_run = [
        (script_id, config)
        for script_id, config in VERIFICATION_SCRIPTS.items()
        if not skip_non_critical or config['critical']
    ]

    emit('all_started', {
        'total': len(scripts_to_run),
        'timestamp': datetime.now().isoformat()
    })

    for script_id, config in scripts_to_run:
        handle_run_script({'script_id': script_id})

    emit('all_completed', {
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/stats')
def get_stats():
    """Get overall statistics"""
    history = load_history()
    latest_results = get_latest_results()

    total_runs = len(history)
    passed = sum(1 for entry in history if entry.get('status') == 'passed')
    failed = sum(1 for entry in history if entry.get('status') == 'failed')

    # Current status
    current_passed = sum(1 for result in latest_results.values() if result.get('status') == 'passed')
    current_failed = sum(1 for result in latest_results.values() if result.get('status') == 'failed')
    total_checks = len(VERIFICATION_SCRIPTS)
    never_run = total_checks - len(latest_results)

    return jsonify({
        'total_runs': total_runs,
        'total_passed': passed,
        'total_failed': failed,
        'current_status': {
            'passed': current_passed,
            'failed': current_failed,
            'never_run': never_run,
            'total_checks': total_checks
        }
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)), debug=False)
