import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('categories')
export class Category {
  @PrimaryColumn({ type: 'text' })
  id: string;

  @Column({ type: 'int', default: 0 })
  version: number;

  @Column({ type: 'text' })
  userId: string;

  @Column({ type: 'text' })
  name: string;

  @Column({ type: 'text', default: '' })
  description: string;

  @Column({ type: 'text', default: '#4CAF50' })
  color: string;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @Column({ type: 'text' })
  createdAt: string;

  @Column({ type: 'text' })
  updatedAt: string;

  @Column({ type: 'text', nullable: true })
  deletedAt: string | null;
}
