import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { SyncModule } from './sync/sync.module';
import { User } from './auth/user.entity';
import { RefreshToken } from './auth/refresh-token.entity';
import { ServerSequence } from './sync/entities/server-sequence.entity';
import { SyncLog } from './sync/entities/sync-log.entity';
import { Todo } from './sync/entities/todo.entity';
import { Category } from './sync/entities/category.entity';
import { ProcessedEntry } from './sync/entities/processed-entry.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'sqljs',
      location: './data/sync.db',
      autoSave: true,
      entities: [User, RefreshToken, ServerSequence, SyncLog, Todo, Category, ProcessedEntry],
      synchronize: true,
    }),
    AuthModule,
    SyncModule,
  ],
})
export class AppModule {}
