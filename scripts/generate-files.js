const fs = require('fs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const path = require('path');

// Get project directories
const ROOT_DIR = path.join(__dirname, '..');
const DOCKER_DIR = path.join(ROOT_DIR, 'supabase', 'docker');
const ALGOD_DATA_DIR = path.join(ROOT_DIR, 'algod-data'); // Changed to root directory

// Function to generate a secure random string
function generateSecret(length = 32) {
    return crypto.randomBytes(length).toString('base64');
}

// Function to generate a Voi node token
function generateNodeToken() {
    return crypto.randomBytes(32).toString('hex');
}

// Function to generate JWT tokens
function generateJWTTokens(secret) {
    const anonToken = jwt.sign({
        role: 'anon',
        iss: 'supabase',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (10 * 365 * 24 * 60 * 60), // 10 years
    }, secret);

    const serviceToken = jwt.sign({
        role: 'service_role',
        iss: 'supabase',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (10 * 365 * 24 * 60 * 60), // 10 years
    }, secret);

    return { anonToken, serviceToken };
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

// Function to write token to file
function writeTokenFile(filePath, token) {
    try {
        fs.writeFileSync(filePath, token, { encoding: 'utf8', mode: 0o600 });
        console.log(`Written token to: ${filePath}`);
    } catch (err) {
        console.error(`Error writing token file ${filePath}:`, err);
        throw err;
    }
}

// Read the template file from the templates directory
const templatePath = path.join(ROOT_DIR, 'templates', '.env.template');
fs.readFile(templatePath, 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading .env.template:', err);
        return;
    }

    try {
        // Generate secrets
        const postgresPassword = generateSecret();
        const jwtSecret = generateSecret();
        const dashboardPassword = generateSecret(24);
        const localLogflareKey = generateSecret(16);

        // Generate Voi node tokens
        const nodeToken = generateNodeToken();
        const nodeAdminToken = generateNodeToken();

        // Generate JWT tokens
        const { anonToken, serviceToken } = generateJWTTokens(jwtSecret);

        // Replace the placeholder values
        const newEnv = data
            .replace('your-super-secret-and-long-postgres-password', postgresPassword)
            .replace('your-super-secret-jwt-token-with-at-least-32-characters', jwtSecret)
            .replace('this-is-a-secure-dashboard-password', dashboardPassword)
            .replace('your-super-secret-logflare-key', localLogflareKey)
            .replace(/NODE_TOKEN=.*/, `NODE_TOKEN=${nodeToken}`)
            .replace(/NODE_ADMIN_TOKEN=.*/, `NODE_ADMIN_TOKEN=${nodeAdminToken}`)
            .replace(/ANON_KEY=.*/, `ANON_KEY=${anonToken}`)
            .replace(/SERVICE_ROLE_KEY=.*/, `SERVICE_ROLE_KEY=${serviceToken}`);

        // Create the algod data directory in the root
        ensureDirectoryExists(ALGOD_DATA_DIR);

        // Write token files to root directory
        writeTokenFile(path.join(ALGOD_DATA_DIR, 'algod.token'), nodeToken);
        writeTokenFile(path.join(ALGOD_DATA_DIR, 'algod.admin.token'), nodeAdminToken);

        // Write the .env file to the docker directory
        const dockerEnvPath = path.join(DOCKER_DIR, '.env');
        fs.writeFileSync(dockerEnvPath, newEnv, 'utf8');
        console.log('Successfully generated .env file in docker directory!');

        // Log the generated values
        console.log('\nGenerated values:');
        console.log('=================');
        console.log('POSTGRES_PASSWORD:', postgresPassword);
        console.log('JWT_SECRET:', jwtSecret);
        console.log('DASHBOARD_PASSWORD:', dashboardPassword);
        console.log('\nVoi Node Configuration:');
        console.log('NODE_TOKEN:', nodeToken);
        console.log('NODE_ADMIN_TOKEN:', nodeAdminToken);
        console.log('Token files created in:', ALGOD_DATA_DIR);
        console.log('\nANON_KEY:', anonToken);
        console.log('\nSERVICE_ROLE_KEY:', serviceToken);
        console.log('\nLocal Analytics Configuration:');
        console.log('LOGFLARE_API_KEY:', localLogflareKey);

        console.log('\nNOTE: This setup uses Postgres as the analytics backend.');
        console.log('If you want to use Logflare\'s hosted service:');
        console.log('1. Sign up at https://logflare.app');
        console.log('2. Get your API key from the Logflare dashboard');
        console.log('3. Replace the LOGFLARE_API_KEY in .env with your actual key');
        console.log('4. Uncomment the BigQuery configuration in docker-compose.yml');
    } catch (error) {
        console.error('An error occurred:', error);
        process.exit(1);
    }
});