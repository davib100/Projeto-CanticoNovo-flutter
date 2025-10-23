import { v4 as uuidv4 } from 'uuid';
import UAParser from 'ua-parser-js';

export function generateDeviceId() {
  return uuidv4();
}

export function parseUserAgent(userAgent) {
  const parser = new UAParser(userAgent);
  const result = parser.getResult();

  return {
    deviceName: `${result.browser.name || 'Unknown'} on ${result.os.name || 'Unknown'}`,
    deviceType: result.device.type || 'web',
    deviceOs: `${result.os.name || 'Unknown'} ${result.os.version || ''}`.trim(),
    browser: result.browser.name,
    browserVersion: result.browser.version,
  };
}

export default {
  generateDeviceId,
  parseUserAgent,
};
