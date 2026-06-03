import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('server_sequence')
export class ServerSequence {
  @PrimaryColumn({ type: 'int' })
  id: number;

  @Column({ type: 'int', default: 0 })
  current: number;
}
