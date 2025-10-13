/**
 * Valida se é UUID válido
 */
export function isValidUUID(str) {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
  }
  
  /**
   * Valida email
   */
  export function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }
  
  /**
   * Valida paginação
   */
  export function validatePagination(limit, offset) {
    const parsedLimit = parseInt(limit, 10);
    const parsedOffset = parseInt(offset, 10);
  
    if (isNaN(parsedLimit) || parsedLimit < 1) {
      throw new Error('Invalid limit parameter');
    }
  
    if (isNaN(parsedOffset) || parsedOffset < 0) {
      throw new Error('Invalid offset parameter');
    }
  
    return { limit: parsedLimit, offset: parsedOffset };
  }
  