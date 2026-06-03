import { Entity, PrimaryColumn, Column, Index } from 'typeorm';

@Entity('refresh_tokens')
@Index(['userId'])
export class RefreshToken {
  @PrimaryColumn({ type: 'text' })
  id: string;

  @Column({ type: 'text' })
  userId: string;

  @Column({ type: 'text' })
  tokenHash: string;

  @Column({ type: 'text' })
  createdAt: string;

  @Column({ type: 'boolean', default: true })
  valid: boolean;
}
