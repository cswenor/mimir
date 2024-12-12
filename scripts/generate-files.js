const fs = require('fs');
const path = require('path');

// Get the root directory (one level up from scripts)
const rootDir = path.join(__dirname, '..');

// Configure dotenv to look in the root directory
require('dotenv').config({ path: path.join(rootDir, '.env') });

// Debug logging for environment variables
console.log('Loading environment from:', path.join(rootDir, '.env'));
if (process.env.DEBUG) {
    console.log('Environment variables loaded:', {
        NODE_TOKEN: process.env.NODE_TOKEN ? 'set' : 'not set',
        NODE_ADMIN_TOKEN: process.env.NODE_ADMIN_TOKEN ? 'set' : 'not set',
        POSTGRES_PASSWORD: process.env.POSTGRES_PASSWORD ? 'set' : 'not set'
    });
}

// Function to ensure directory exists
function ensureDirectoryExists(dirPath) {
    try {
        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath, { recursive: true });
            console.log(`Created directory: ${dirPath}`);
        }
    } catch (err) {
        console.error(`Error creating directory ${dirPath}:`, err);
        throw err;
    }
}

// Function to write token file
function writeTokenFile(filePath, token) {
    try {
        if (!token) {
            throw new Error(`No token provided for ${filePath}`);
        }
        fs.writeFileSync(filePath, token, { encoding: 'utf8', mode: 0o600 });
        console.log(`Written token to: ${filePath}`);
    } catch (err) {
        console.error(`Error writing token file ${filePath}:`, err);
        throw err;
    }
}

// Function to generate conduit config
function generateConduitConfig() {
    // This is a placeholder for the actual conduit configuration
    return `
version: 3
network: voi
follow:
  data-dir: /algod/data
  node-url: "/algorand"
  node-token: "${process.env.NODE_TOKEN}"
process:
  max-connection-idle-time: 0
  filter:
    # add any desired filters
    min-round: 0
import:
  mode: "postgres"
  postgres:
    connection-string: "host=postgres port=5432 user=postgres password=${process.env.POSTGRES_PASSWORD} dbname=postgres sslmode=disable"
    max-conn: 10
    min-conn: 1
`;
}

try {
    // First verify .env file exists
    const envFile = path.join(rootDir, '.env');
    if (!fs.existsSync(envFile)) {
        throw new Error(`.env file not found at ${envFile}. Please run generate-env.js first.`);
    }

    // Check if required environment variables exist
    const requiredEnvVars = ['NODE_TOKEN', 'NODE_ADMIN_TOKEN', 'POSTGRES_PASSWORD'];
    const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
        throw new Error(
            `Missing required environment variables: ${missingVars.join(', ')}\n` +
            `Checked .env file at: ${envFile}\n` +
            'Please ensure these variables are set in your .env file.'
        );
    }

    // Ensure algod data directory exists
    const algodDataDir = path.join(rootDir, 'algod-data');
    ensureDirectoryExists(algodDataDir);

    // Ensure conduit data directory exists
    const conduitDataDir = path.join(rootDir, 'conduit-data');
    ensureDirectoryExists(conduitDataDir);

    // Write token files
    writeTokenFile(
        path.join(algodDataDir, 'algod.token'),
        process.env.NODE_TOKEN
    );
    writeTokenFile(
        path.join(algodDataDir, 'algod.admin.token'),
        process.env.NODE_ADMIN_TOKEN
    );

    // Generate and write conduit config
    const conduitConfig = generateConduitConfig();
    fs.writeFileSync(
        path.join(conduitDataDir, 'conduit.yml'),
        conduitConfig,
        'utf8'
    );
    console.log('Generated conduit.yml');

    console.log('Successfully generated all required files!');
} catch (error) {
    console.error('Error generating files:', error);
    process.exit(1);
}