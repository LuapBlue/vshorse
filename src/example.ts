/**
 * Example TypeScript file demonstrating clean typing practices
 */

// Interface with clear naming and strict typing
export interface IUserData {
  readonly id: string;
  name: string;
  email: string;
  createdAt: Date;
  metadata?: Record<string, unknown>;
}

// Type alias for complex types
export type UserRole = 'admin' | 'user' | 'guest';

// Class with proper typing
export class UserService {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  /**
   * Fetch user data with explicit return type
   */
  public async getUser(userId: string): Promise<IUserData> {
    const response = await fetch(`${this.baseUrl}/users/${userId}`);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch user: ${response.statusText}`);
    }

    const data = await response.json() as IUserData;
    return data;
  }

  /**
   * Create a new user with validation
   */
  public async createUser(
    userData: Omit<IUserData, 'id' | 'createdAt'>
  ): Promise<IUserData> {
    const response = await fetch(`${this.baseUrl}/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(userData),
    });

    if (!response.ok) {
      throw new Error(`Failed to create user: ${response.statusText}`);
    }

    const newUser = await response.json() as IUserData;
    return newUser;
  }
}

// Example usage with proper error handling
export async function exampleUsage(): Promise<void> {
  const userService = new UserService('http://localhost:8000/api');
  
  try {
    const newUser = await userService.createUser({
      name: 'John Doe',
      email: 'john@example.com',
    });
    
    console.log('User created:', newUser);
  } catch (error) {
    console.error('Error creating user:', error);
  }
}
