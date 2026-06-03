import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('processed_entries')
export class ProcessedEntry {
  @PrimaryColumn({ type: 'text' })
  entryId: string;

  @Column({ type: 'int' })
  serverSequence: number;
}
