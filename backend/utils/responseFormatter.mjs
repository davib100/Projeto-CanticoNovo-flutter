/**
 * Formata resposta de sucesso
 */
export function formatSuccess(data, message = null) {
    return {
      success: true,
      data,
      ...(message && { message }),
      timestamp: new Date().toISOString(),
    };
  }
  
  /**
   * Formata resposta de erro
   */
  export function formatError(code, message, details = null) {
    return {
      success: false,
      error: {
        code,
        message,
        ...(details && { details }),
      },
      timestamp: new Date().toISOString(),
    };
  }
  