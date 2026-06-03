import { Entity, PrimaryColumn, Column, Index } from 'typeorm';

@Entity('todos')
@Index(['userId'])
export class Todo {
  @PrimaryColumn({ type: 'text' })
  id: string;

  @Column({ type: 'int', default: 0 })
  version: number;

  @Column({ type: 'text' })
  userId: string;

  @Column({ type: 'text' })
  title: string;

  @Column({ type: 'text', default: '' })
  description: string;

  @Column({ type: 'int', default: 0 })
  isDone: number;

  @Column({ type: 'text' })
  createdAt: string;

  @Column({ type: 'text' })
  updatedAt: string;

  @Column({ type: 'text', nullable: true })
  deletedAt: string | null;
}
