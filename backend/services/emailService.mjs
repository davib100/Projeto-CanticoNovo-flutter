import nodemailer from 'nodemailer';
import { config } from '../config/env.mjs';

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      host: config.EMAIL_HOST,
      port: config.EMAIL_PORT,
      secure: false,
      auth: {
        user: config.EMAIL_USER,
        pass: config.EMAIL_PASSWORD,
      },
    });
  }

  async sendPasswordResetEmail(email, resetToken) {
    const resetLink = `${config.FRONTEND_URL}/reset-password?token=${resetToken}`;

    const mailOptions = {
      from: config.EMAIL_FROM,
      to: email,
      subject: 'Redefinição de Senha - Cântico Novo',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
            <tr>
              <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                  <tr>
                    <td style="background: linear-gradient(135deg, #FBBF24 0%, #F59E0B 100%); padding: 40px 20px; text-align: center;">
                      <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎵 Cântico Novo</h1>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 40px 30px;">
                      <h2 style="color: #333; margin-top: 0;">Redefinir sua senha</h2>
                      <p style="color: #666; line-height: 1.6; font-size: 16px;">
                        Você solicitou a redefinição de senha da sua conta. Clique no botão abaixo para criar uma nova senha:
                      </p>
                      <div style="text-align: center; margin: 30px 0;">
                        <a href="${resetLink}" style="background: linear-gradient(135deg, #FBBF24 0%, #F59E0B 100%); color: #ffffff; padding: 14px 40px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                          Redefinir Senha
                        </a>
                      </div>
                      <p style="color: #666; line-height: 1.6; font-size: 14px;">
                        Se você não solicitou esta redefinição, ignore este email. Seu link expira em 1 hora.
                      </p>
                      <p style="color: #999; line-height: 1.6; font-size: 12px; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">
                        Se o botão não funcionar, copie e cole este link no navegador:<br>
                        <a href="${resetLink}" style="color: #F59E0B; word-break: break-all;">${resetLink}</a>
                      </p>
                    </td>
                  </tr>
                  <tr>
                    <td style="background-color: #f9f9f9; padding: 20px; text-align: center; color: #999; font-size: 12px;">
                      <p style="margin: 0;">© ${new Date().getFullYear()} Cântico Novo. Todos os direitos reservados.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
      `,
    };

    await this.transporter.sendMail(mailOptions);
  }

  async sendWelcomeEmail(email, fullName) {
    const mailOptions = {
      from: config.EMAIL_FROM,
      to: email,
      subject: 'Bem-vindo ao Cântico Novo! 🎵',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
        </head>
        <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden;">
            <div style="background: linear-gradient(135deg, #FBBF24 0%, #F59E0B 100%); padding: 40px 20px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0;">🎵 Cântico Novo</h1>
            </div>
            <div style="padding: 40px 30px;">
              <h2 style="color: #333;">Olá, ${fullName}!</h2>
              <p style="color: #666; line-height: 1.6;">
                Bem-vindo ao Cântico Novo! Estamos felizes em ter você conosco.
              </p>
              <p style="color: #666; line-height: 1.6;">
                Com o Cântico Novo, você pode gerenciar suas letras favoritas, criar playlists e muito mais!
              </p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    await this.transporter.sendMail(mailOptions);
  }
}

export default new EmailService();
