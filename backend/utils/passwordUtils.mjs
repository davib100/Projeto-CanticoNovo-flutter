import bcrypt from 'bcryptjs';
import { config } from '../config/env.mjs';

export async function hashPassword(password) {
  return await bcrypt.hash(password, config.BCRYPT_ROUNDS);
}

export async function comparePassword(password, hash) {
  return await bcrypt.compare(password, hash);
}

export function validatePasswordStrength(password) {
  const errors = [];

  if (password.length < 8) {
    errors.push('Senha deve ter pelo menos 8 caracteres');
  }

  if (!/[a-z]/.test(password)) {
    errors.push('Senha deve conter letras minúsculas');
  }

  if (!/[A-Z]/.test(password)) {
    errors.push('Senha deve conter letras maiúsculas');
  }

  if (!/\d/.test(password)) {
    errors.push('Senha deve conter números');
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

export default {
  hashPassword,
  comparePassword,
  validatePasswordStrength,
};
