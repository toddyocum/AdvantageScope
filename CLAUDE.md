# AdvantageScope Development Guide

## Commands
- Build: `npm run build` - Full build process
- Fast build: `npm run fast-build` - Faster build (skips some steps)
- Development: `npm run watch` → `npm start` - Watch for changes and run app
- Format code: `npm run format` - Format using Prettier
- Check format: `npm run check-format` - Verify formatting

## Code Style Guidelines
- **TypeScript**: Use strict typing with ESNext target
- **Formatting**: 120 character line width, no trailing commas
- **Imports**: Use ES modules, organized with prettier-plugin-organize-imports
- **Naming**: PascalCase for classes/interfaces, camelCase for variables/functions
- **File Structure**: Components in src/ compiled to bundles/
- **Error Handling**: Use TypeScript's strict null checking
- **Documentation**: Document APIs and complex functions with JSDoc-style comments