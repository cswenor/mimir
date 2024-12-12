require('dotenv').config();
const fs = require('fs');
const path = require('path');

function ensureDirectoryExists(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
        console.log(`Created directory: ${dirPath}`);
    }
}

function writeTokenFile(filePath, token) {
    fs.writeFileSync(filePath, token, { encoding: 'utf8', mode: 0o600 });
    console.log(`Written token to: ${filePath}`);
}

function generateConduitConfig() {
    const template = fs.readFileSync(
        path.join(__dirname, '../templates/conduit.yml.template'),
        'utf8'
    );
    // TODO: Replace placeholders in template with actual values
    return template;
}

// Main execution
try {
    // Ensure directories exist
    ensureDirectoryExists(path.join(__dirname, '../algod-data'));
    ensureDirectoryExists(path.join(__dirname, '../conduit-data'));

    // Write node tokens
    writeTokenFile(
        path.join(__dirname, '../algod-data/algod.token'),
        process.env.NODE_TOKEN
    );
    writeTokenFile(
        path.join(__dirname, '../algod-data/algod.admin.token'),
        process.env.NODE_ADMIN_TOKEN
    );

    // Generate and write conduit config
    const conduitConfig = generateConduitConfig();
    fs.writeFileSync(
        path.join(__dirname, '../conduit-data/conduit.yml'),
        conduitConfig,
        'utf8'
    );

    console.log('Successfully generated all required files!');
} catch (error) {
    console.error('Error generating files:', error);
    process.exit(1);
}