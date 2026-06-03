import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

@Entity('sync_log')
@Index(['entityType', 'userId', 'serverSequence'])
export class SyncLog {
  @PrimaryGeneratedColumn({ type: 'int' })
  id: number;

  @Column({ type: 'int', unique: true })
  serverSequence: number;

  @Column({ type: 'text' })
  userId: string;

  @Column({ type: 'text' })
  entityType: string;

  @Column({ type: 'text' })
  entityId: string;

  @Column({ type: 'text' })
  operation: string;

  @Column({ type: 'text' })
  payload: string;

  @Column({ type: 'text', default: () => "datetime('now')" })
  createdAt: string;
}
