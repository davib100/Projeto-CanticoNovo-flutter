import winston from 'winston';
import path from 'path';
import fs from 'fs';
import { config } from '../config/env.mjs';

// Garante que o diretório de logs existe
if (!fs.existsSync(config.LOG_FILE_PATH)) {
  fs.mkdirSync(config.LOG_FILE_PATH, { recursive: true });
}

// Formato personalizado
const customFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Console format (colorido)
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.printf(({ level, message, timestamp, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta) : '';
    return `${timestamp} [${level}]: ${message} ${metaStr}`;
  })
);

// Transportes
const transports = [
  // Console
  new winston.transports.Console({
    format: consoleFormat,
    level: config.LOG_LEVEL,
  }),

  // Arquivo de erros
  new winston.transports.File({
    filename: path.join(config.LOG_FILE_PATH, 'error.log'),
    level: 'error',
    format: customFormat,
    maxsize: 5242880, // 5MB
    maxFiles: 5,
  }),

  // Arquivo combinado
  new winston.transports.File({
    filename: path.join(config.LOG_FILE_PATH, 'combined.log'),
    format: customFormat,
    maxsize: 5242880, // 5MB
    maxFiles: 5,
  }),
];

// Cria logger
export const logger = winston.createLogger({
  level: config.LOG_LEVEL,
  format: customFormat,
  transports,
  exitOnError: false,
});

// Stream para Morgan (se necessário)
logger.stream = {
  write: (message) => {
    logger.info(message.trim());
  },
};
