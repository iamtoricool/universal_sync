import { IsEmail, IsString, MinLength } from 'class-validator';

export class SignupDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;
}

export class SigninDto {
  @IsEmail()
  email: string;

  @IsString()
  password: string;
}

export class RefreshDto {
  @IsString()
  refreshToken: string;
}

export class SignoutDto {
  @IsString()
  refreshToken: string;
}

export class AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export class AuthResponse {
  tokens: AuthTokens;
  user: { id: string; email: string };
}
