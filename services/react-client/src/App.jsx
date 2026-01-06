import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [status, setStatus] = useState({
    r2r: 'checking',
    openwebui: 'checking',
    litellm: 'checking',
  });

  useEffect(() => {
    // Check backend service availability
    const checkServices = async () => {
      const r2rUrl = import.meta.env.VITE_R2R_URL || 'http://r2r.railway.internal:7272';
      const openwebUIUrl = import.meta.env.VITE_OPENWEBUI_URL || 'http://openwebui.railway.internal:8080';
      const litellmUrl = import.meta.env.VITE_LITELLM_URL || 'http://litellm.railway.internal:4000';

      // Check each service with a health endpoint
      const services = {
        r2r: `${r2rUrl}/health`,
        openwebui: `${openwebUIUrl}/`,
        litellm: `${litellmUrl}/health`,
      };

      for (const [name, url] of Object.entries(services)) {
        try {
          const response = await fetch(url, {
            method: 'GET',
            mode: 'no-cors',
          });
          setStatus((prev) => ({ ...prev, [name]: 'online' }));
        } catch (error) {
          setStatus((prev) => ({ ...prev, [name]: 'offline' }));
        }
      }
    };

    checkServices();
    const interval = setInterval(checkServices, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="container">
      <header className="header">
        <h1>🚀 LLM Stack - React Client</h1>
        <p className="subtitle">Hello World from Railway</p>
      </header>

      <main className="main">
        <section className="services-section">
          <h2>Backend Services Status</h2>
          
          <div className="services-grid">
            <div className="service-card">
              <h3>R2R Service</h3>
              <div className="url-display">
                {import.meta.env.VITE_R2R_URL || 'http://r2r.railway.internal:7272'}
              </div>
              <div className={`status-badge ${status.r2r}`}>
                {status.r2r === 'checking' ? '⏳' : status.r2r === 'online' ? '✅ Online' : '❌ Offline'}
              </div>
            </div>

            <div className="service-card">
              <h3>OpenWebUI Service</h3>
              <div className="url-display">
                {import.meta.env.VITE_OPENWEBUI_URL || 'http://openwebui.railway.internal:8080'}
              </div>
              <div className={`status-badge ${status.openwebui}`}>
                {status.openwebui === 'checking' ? '⏳' : status.openwebui === 'online' ? '✅ Online' : '❌ Offline'}
              </div>
            </div>

            <div className="service-card">
              <h3>LiteLLM Service</h3>
              <div className="url-display">
                {import.meta.env.VITE_LITELLM_URL || 'http://litellm.railway.internal:4000'}
              </div>
              <div className={`status-badge ${status.litellm}`}>
                {status.litellm === 'checking' ? '⏳' : status.litellm === 'online' ? '✅ Online' : '❌ Offline'}
              </div>
            </div>
          </div>
        </section>

        <section className="info-section">
          <h2>About This Stack</h2>
          <div className="info-card">
            <p>
              This is a minimal React Hello World application running as part of the LLM Stack 
              on Railway. It demonstrates integration with multiple backend services including R2R 
              for document processing, OpenWebUI for LLM interactions, and LiteLLM for model routing.
            </p>
            <p>
              <strong>Environment Variables:</strong>
            </p>
            <ul>
              <li><code>VITE_R2R_URL</code> - R2R backend endpoint</li>
              <li><code>VITE_OPENWEBUI_URL</code> - OpenWebUI backend endpoint</li>
              <li><code>VITE_LITELLM_URL</code> - LiteLLM backend endpoint</li>
            </ul>
          </div>
        </section>
      </main>

      <footer className="footer">
        <p>Built with React 18 • Served by Nginx • Deployed on Railway</p>
      </footer>
    </div>
  );
}

export default App;
