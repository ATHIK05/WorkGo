const fs = require('fs');
const path = require('path');
const { GoogleAuth } = require('google-auth-library');

async function deployFirestoreRules() {
  const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
  const rulesPath = path.resolve(__dirname, '../../firestore.rules');

  if (!fs.existsSync(saPath)) {
    throw new Error(`Service account key not found at: ${saPath}`);
  }
  if (!fs.existsSync(rulesPath)) {
    throw new Error(`firestore.rules not found at: ${rulesPath}`);
  }

  const rulesContent = fs.readFileSync(rulesPath, 'utf8');
  console.log(`Read firestore.rules (${rulesContent.length} bytes).`);

  const auth = new GoogleAuth({
    keyFile: saPath,
    scopes: [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/firebase'
    ]
  });

  const client = await auth.getClient();
  const tokenRes = await client.getAccessToken();
  const accessToken = tokenRes.token;
  console.log('✓ Google OAuth2 access token acquired successfully.');

  const projectId = 'workgo-sih2026';

  // 1. Create Ruleset
  console.log('Creating ruleset via Firebase Rules REST API...');
  const createRes = await fetch(`https://firebaserules.googleapis.com/v1/projects/${projectId}/rulesets`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      source: {
        files: [
          {
            name: 'firestore.rules',
            content: rulesContent
          }
        ]
      }
    })
  });

  const createData = await createRes.json();
  if (!createRes.ok) {
    console.error('Failed to create ruleset:', createData);
    process.exit(1);
  }
  console.log('✓ Created Ruleset:', createData.name);

  // 2. Release Ruleset to cloud.firestore
  console.log('Releasing ruleset to release: cloud.firestore...');
  const releaseRes = await fetch(`https://firebaserules.googleapis.com/v1/projects/${projectId}/releases/cloud.firestore`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      release: {
        name: `projects/${projectId}/releases/cloud.firestore`,
        rulesetName: createData.name
      }
    })
  });

  const releaseData = await releaseRes.json();
  if (!releaseRes.ok) {
    // If release resource doesn't exist yet, create it via POST
    console.log('PATCH returned non-ok, attempting POST to create release resource...');
    const postReleaseRes = await fetch(`https://firebaserules.googleapis.com/v1/projects/${projectId}/releases`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        name: `projects/${projectId}/releases/cloud.firestore`,
        rulesetName: createData.name
      })
    });
    const postReleaseData = await postReleaseRes.json();
    if (!postReleaseRes.ok) {
      console.error('Failed to release ruleset via POST:', postReleaseData);
      process.exit(1);
    }
    console.log('✓ Successfully created and published release via POST:', postReleaseData.name);
  } else {
    console.log('✓ Successfully updated and published release via PATCH:', releaseData.name);
  }

  console.log('\n🎉 SUCCESS: Firestore rules are LIVE in workgo-sih2026!');
}

deployFirestoreRules().catch(err => {
  console.error('Deployment error:', err);
  process.exit(1);
});
