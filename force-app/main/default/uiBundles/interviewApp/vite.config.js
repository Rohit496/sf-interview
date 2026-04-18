import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    server: {
        port: 5173,
        // Allow the sf ui-bundle proxy (default port 4545) to connect
        cors: true,
        headers: {
            'Access-Control-Allow-Origin': '*'
        }
    }
});
