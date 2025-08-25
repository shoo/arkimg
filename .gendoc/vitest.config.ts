import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
	plugins: [vue()],
	resolve: {
		alias: {
			'@': path.resolve(__dirname, 'src')
		}
	},
	test: {
		globals: true,
		environment: 'jsdom',
		setupFiles: './tests/setupTests.ts',
		coverage: {
			provider: 'v8',
			reporter: ['text', 'html', 'json'],
			reportsDirectory: './coverage',
			exclude: ['node_modules/', 'tests/', "*.config.ts", "*.config.*.ts", "*.config.mjs", "public/", "src/main.ts"],
		},
	},
	esbuild: {
		sourcemap: true
	}
})
