import { mergeConfig } from 'vite';
import baseConfig from './vite.config';

export default mergeConfig(baseConfig, {
	server: {
		host: true,
		watch: {
			usePolling: true
		},
		hmr: {
			host: 'localhost',
			port: 5173
		}
	}
});
