import axios from 'axios';
import { googleConfig } from '../config/oauth.mjs';

export class OAuthService {
  static async verifyGoogleToken(idToken) {
    try {
      const response = await axios.get(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`
      );

      const data = response.data;

      if (!data.email_verified) {
        throw new Error('Email não verificado');
      }

      return {
        oauthId: data.sub,
        email: data.email,
        fullName: data.name,
        photoUrl: data.picture,
      };
    } catch (error) {
      throw new Error('Token do Google inválido');
    }
  }

  static async verifyMicrosoftToken(accessToken) {
    try {
      const response = await axios.get('https://graph.microsoft.com/v1.0/me', {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      const data = response.data;

      return {
        oauthId: data.id,
        email: data.mail || data.userPrincipalName,
        fullName: data.displayName,
        photoUrl: null, // Microsoft não fornece foto na API básica
      };
    } catch (error) {
      throw new Error('Token da Microsoft inválido');
    }
  }

  static async verifyFacebookToken(accessToken) {
    try {
      const response = await axios.get(
        `https://graph.facebook.com/me?fields=id,name,email,picture&access_token=${accessToken}`
      );

      const data = response.data;

      return {
        oauthId: data.id,
        email: data.email,
        fullName: data.name,
        photoUrl: data.picture?.data?.url,
      };
    } catch (error) {
      throw new Error('Token do Facebook inválido');
    }
  }
}

export default OAuthService;
