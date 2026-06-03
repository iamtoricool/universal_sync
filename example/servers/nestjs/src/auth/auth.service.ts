import { createHash } from 'crypto';
import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { v4 as uuid } from 'uuid';
import { User } from './user.entity';
import { RefreshToken } from './refresh-token.entity';
import { AuthResponse } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepo: Repository<RefreshToken>,
    private readonly jwtService: JwtService,
  ) {}

  private readonly refreshExpiresIn = '30d';

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async issueTokens(userId: string, email: string): Promise<{ accessToken: string; refreshToken: string }> {
    const accessToken = this.jwtService.sign({ sub: userId, email });
    const refreshToken = this.jwtService.sign({ sub: userId, email, type: 'refresh' }, { expiresIn: this.refreshExpiresIn });
    const now = new Date().toISOString();
    await this.refreshTokenRepo.insert({
      id: uuid(),
      userId,
      tokenHash: this.hashToken(refreshToken),
      createdAt: now,
      valid: true,
    });
    return { accessToken, refreshToken };
  }

  async signup(email: string, password: string): Promise<AuthResponse> {
    const existing = await this.userRepo.findOneBy({ email });
    if (existing) {
      throw new ConflictException('email already registered');
    }
    const id = uuid();
    const passwordHash = await bcrypt.hash(password, 10);
    const now = new Date().toISOString();
    await this.userRepo.insert({ id, email, passwordHash, createdAt: now });
    const tokens = await this.issueTokens(id, email);
    return { tokens, user: { id, email } };
  }

  async signin(email: string, password: string): Promise<AuthResponse> {
    const user = await this.userRepo.findOneBy({ email });
    if (!user) {
      throw new UnauthorizedException('invalid email or password');
    }
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('invalid email or password');
    }
    const tokens = await this.issueTokens(user.id, user.email);
    return { tokens, user: { id: user.id, email: user.email } };
  }

  async refresh(refreshToken: string): Promise<AuthResponse> {
    let payload: { sub: string; email: string; type?: string };
    try {
      payload = this.jwtService.verify(refreshToken) as any;
    } catch {
      throw new UnauthorizedException('invalid or expired refresh token');
    }
    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('invalid token type');
    }
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.refreshTokenRepo.findOneBy({ tokenHash });
    if (!stored || !stored.valid) {
      throw new UnauthorizedException('refresh token has been revoked');
    }
    const user = await this.userRepo.findOneBy({ id: payload.sub });
    if (!user) {
      throw new UnauthorizedException('user not found');
    }
    stored.valid = false;
    await this.refreshTokenRepo.save(stored);
    const tokens = await this.issueTokens(user.id, user.email);
    return { tokens, user: { id: user.id, email: user.email } };
  }

  async signout(userId: string, refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.refreshTokenRepo.findOneBy({ tokenHash, userId });
    if (stored) {
      stored.valid = false;
      await this.refreshTokenRepo.save(stored);
    }
  }

  async me(userId: string): Promise<{ id: string; email: string; createdAt: string }> {
    const user = await this.userRepo.findOneBy({ id: userId });
    if (!user) {
      throw new UnauthorizedException('user not found');
    }
    return { id: user.id, email: user.email, createdAt: user.createdAt };
  }
}
