import fetch from ‘node-fetch’
import * as fs from ‘fs’
import * as https from ‘https’
import * as path from ‘path’;
const httpsAgent = new https.Agent({
    rejectUnauthorized: false,
    cert: fs.readFileSync(
        path.resolve(__dirname, ‘./../client-cert.pem’),
        `utf-8`,
    ),
    key: fs.readFileSync(
        path.resolve(__dirname, ‘./../client-key.pem’),
        ‘utf-8’,
    ),
});
const requestBody = JSON.stringify({
    “@type”: “powerSwitchState”,
    “switchState”: “OFF”
});
const requestOptions = {
    method: ‘PUT’,
    cert: fs.readFileSync,
    agent: httpsAgent,
    body: requestBody,
    headers: { “Content-Type”: “application/json” }
};
async function main() {
    const res = await fetch(“https://10.51.204.107:8444/smarthome/devices/hdm%3AHomeMaticIP%3A3014F711A00004953859E5E2/services/PowerSwitch/state”, requestOptions);
    console.log(res.status)
}
main();
14:35 Uhr
import fetch from ‘node-fetch’
import * as https from ‘https’
const httpsAgent = new https.Agent({
    rejectUnauthorized: false,
    cert: `-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
`,
    key: `-----BEGIN PRIVATE KEY-----
-----END PRIVATE KEY-----`,
});
const requestBody = JSON.stringify({
    “@type”: “powerSwitchState”,
    “switchState”: “OFF”
});
const requestOptions = {
    method: ‘PUT’,
    agent: httpsAgent,
    body: requestBody,
    headers: { “Content-Type”: “application/json” }
};
async function main() {
    const res = await fetch(“https://10.51.204.107:8444/smarthome/devices/hdm%3AHomeMaticIP%3A3014F711A00004953859E5E2/services/PowerSwitch/state”, requestOptions);
    console.log(res.status)
}
main();