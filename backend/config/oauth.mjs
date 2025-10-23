import { config } from './env.mjs';

export const googleConfig = {
  clientId: config.GOOGLE_CLIENT_ID,
  clientSecret: config.GOOGLE_CLIENT_SECRET,
  redirectUri: config.GOOGLE_REDIRECT_URI,
  scope: ['email', 'profile'],
  authorizationURL: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenURL: 'https://oauth2.googleapis.com/token',
  userInfoURL: 'https://www.googleapis.com/oauth2/v2/userinfo',
};

export const microsoftConfig = {
  clientId: config.MICROSOFT_CLIENT_ID,
  clientSecret: config.MICROSOFT_CLIENT_SECRET,
  redirectUri: config.MICROSOFT_REDIRECT_URI,
  scope: ['User.Read'],
  authorizationURL: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
  tokenURL: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
  userInfoURL: 'https://graph.microsoft.com/v1.0/me',
};

export const facebookConfig = {
  appId: config.FACEBOOK_APP_ID,
  appSecret: config.FACEBOOK_APP_SECRET,
  redirectUri: config.FACEBOOK_REDIRECT_URI,
  scope: ['email', 'public_profile'],
  authorizationURL: 'https://www.facebook.com/v12.0/dialog/oauth',
  tokenURL: 'https://graph.facebook.com/v12.0/oauth/access_token',
  userInfoURL: 'https://graph.facebook.com/me',
};

export default {
  google: googleConfig,
  microsoft: microsoftConfig,
  facebook: facebookConfig,
};
