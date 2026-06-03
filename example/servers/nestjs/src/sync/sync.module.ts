import { Module, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { ServerSequence } from './entities/server-sequence.entity';
import { SyncLog } from './entities/sync-log.entity';
import { Todo } from './entities/todo.entity';
import { ProcessedEntry } from './entities/processed-entry.entity';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ServerSequence, SyncLog, Todo, ProcessedEntry]),
    AuthModule,
  ],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule implements OnModuleInit {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async onModuleInit() {
    const seqRepo = this.dataSource.getRepository(ServerSequence);
    const existing = await seqRepo.findOneBy({ id: 1 });
    if (!existing) {
      await seqRepo.insert({ id: 1, current: 0 });
    }
  }
}
