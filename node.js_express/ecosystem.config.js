// ecosystem.config.js - Configuración PM2 para las 3 réplicas
module.exports = {
  apps: [
    {
      name: 'validador-3001',
      script: 'app.js',
      env: { PORT: 3001 },
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 1000,
    },
    {
      name: 'validador-3002',
      script: 'app.js',
      env: { PORT: 3002 },
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 1000,
    },
    {
      name: 'validador-3003',
      script: 'app.js',
      env: { PORT: 3003 },
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 1000,
    },
  ],
};
