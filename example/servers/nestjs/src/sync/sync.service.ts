import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, MoreThan } from 'typeorm';
import { ServerSequence } from './entities/server-sequence.entity';
import { SyncLog } from './entities/sync-log.entity';
import { Todo } from './entities/todo.entity';
import { Category } from './entities/category.entity';
import { ProcessedEntry } from './entities/processed-entry.entity';
import { PushEntryDto } from './dto/push-request.dto';
import { SyncEntryResultDto, PushResponseDto } from './dto/push-response.dto';
import { PullResponseDto, RemoteOperationDto } from './dto/pull-response.dto';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    @InjectRepository(ServerSequence)
    private readonly seqRepo: Repository<ServerSequence>,
    @InjectRepository(SyncLog)
    private readonly syncLogRepo: Repository<SyncLog>,
    @InjectRepository(Todo)
    private readonly todoRepo: Repository<Todo>,
    @InjectRepository(Category)
    private readonly categoryRepo: Repository<Category>,
    @InjectRepository(ProcessedEntry)
    private readonly processedEntryRepo: Repository<ProcessedEntry>,
    private readonly dataSource: DataSource,
  ) {}

  async handlePush(entries: PushEntryDto[], userId: string): Promise<PushResponseDto> {
    const results: SyncEntryResultDto[] = [];

    await this.dataSource.transaction(async (txManager) => {
      for (const entry of entries) {
        try {
          const result = await this.processEntry(txManager, entry, userId);
          results.push(result);
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          this.logger.warn(`Push entry ${entry.id} failed: ${message}`);
          results.push(new SyncEntryResultDto({
            entryId: entry.id,
            outcome: 'rejected',
            errorMessage: message,
          }));
        }
      }
    });

    return new PushResponseDto(results);
  }

  private async processEntry(
    txManager: any,
    entry: PushEntryDto,
    userId: string,
  ): Promise<SyncEntryResultDto> {
    const processed = await txManager.findOne(ProcessedEntry, {
      where: { entryId: entry.id },
    });
    if (processed) {
      return new SyncEntryResultDto({
        entryId: entry.id,
        outcome: 'accepted',
        serverSequence: processed.serverSequence,
      });
    }

    const seq = await this.nextSequence(txManager);
    const payload = JSON.parse(entry.payload);

    if (entry.entityType === 'Todo') {
      return this.processTodoEntry(txManager, entry, payload, seq, userId);
    }
    if (entry.entityType === 'TodoCategory') {
      return this.processCategoryEntry(txManager, entry, payload, seq, userId);
    }

    await this.logSync(txManager, seq, userId, entry, false);
    return new SyncEntryResultDto({
      entryId: entry.id,
      outcome: 'rejected',
      errorMessage: `unknown entityType: ${entry.entityType}`,
    });
  }

  private async processTodoEntry(
    txManager: any,
    entry: PushEntryDto,
    payload: any,
    seq: number,
    userId: string,
  ): Promise<SyncEntryResultDto> {
    return this.processEntity(
      txManager, entry, payload, seq, userId, Todo,
      (existing) => this.todoToSnake(existing),
      (existing, newVersion) => this.buildTodoUpdate(payload, existing, newVersion),
      () => this.buildTodoInsert(entry.entityId, userId, payload),
    );
  }

  private async processCategoryEntry(
    txManager: any,
    entry: PushEntryDto,
    payload: any,
    seq: number,
    userId: string,
  ): Promise<SyncEntryResultDto> {
    return this.processEntity(
      txManager, entry, payload, seq, userId, Category,
      (existing) => this.categoryToCamel(existing),
      (existing, newVersion) => this.buildCategoryUpdate(payload, existing, newVersion),
      () => this.buildCategoryInsert(entry.entityId, userId, payload),
    );
  }

  private async processEntity(
    txManager: any,
    entry: PushEntryDto,
    payload: any,
    seq: number,
    userId: string,
    entityClass: new () => any,
    toCamelFn: (existing: any) => any,
    buildUpdateFn: (existing: any, newVersion: number) => any,
    buildInsertFn: () => any,
  ): Promise<SyncEntryResultDto> {
    const existing = await txManager.findOne(entityClass, {
      where: { id: entry.entityId },
    });

    if (existing && existing.userId !== userId) {
      await this.logSync(txManager, seq, userId, entry, false);
      return new SyncEntryResultDto({
        entryId: entry.id,
        outcome: 'rejected',
        errorMessage: 'not owned by this user',
      });
    }

    if (entry.operation === 'delete') {
      if (existing) {
        const clientVersion = (payload.version as number) ?? 0;
        if (clientVersion < existing.version) {
          await this.logSync(txManager, seq, userId, entry, false);
          return new SyncEntryResultDto({
            entryId: entry.id,
            outcome: 'conflicted',
            serverPayload: JSON.stringify(toCamelFn(existing)),
          });
        }
      }
      if (existing) {
        await txManager.update(entityClass, entry.entityId, {
          deletedAt: new Date().toISOString(),
        });
      }
      await this.logSync(txManager, seq, userId, entry, false);
    } else if (existing) {
      const clientVersion = (payload.version as number) ?? 0;
      if (clientVersion < existing.version) {
        await this.logSync(txManager, seq, userId, entry, false);
        return new SyncEntryResultDto({
          entryId: entry.id,
          outcome: 'conflicted',
          serverPayload: JSON.stringify(toCamelFn(existing)),
        });
      }
      const newVersion = existing.version + 1;
      await txManager.update(entityClass, entry.entityId, buildUpdateFn(existing, newVersion));
      await this.logSync(txManager, seq, userId, entry, true, newVersion);
    } else {
      await txManager.insert(entityClass, buildInsertFn());
      await this.logSync(txManager, seq, userId, entry, true, 1);
    }

    await txManager.insert(ProcessedEntry, {
      entryId: entry.id,
      serverSequence: seq,
    });
    return new SyncEntryResultDto({
      entryId: entry.id,
      outcome: 'accepted',
      serverSequence: seq,
    });
  }

  async handlePull(
    entityType: string,
    sinceSequence: number,
    userId: string,
  ): Promise<PullResponseDto> {
    const rows = await this.syncLogRepo.find({
      where: { entityType, userId, serverSequence: MoreThan(sinceSequence) },
      order: { serverSequence: 'ASC' },
    });

    const latestSeq = await this.syncLogRepo.findOne({
      where: { entityType, userId },
      order: { serverSequence: 'DESC' },
    });

    const dedupMap = new Map<string, typeof rows[0]>();
    for (const row of rows) {
      dedupMap.set(row.entityId, row);
    }
    const deduplicated = Array.from(dedupMap.values());

    const operations: RemoteOperationDto[] = deduplicated.map((r) => ({
      entityType: r.entityType,
      entityId: r.entityId,
      operation: r.operation,
      payload: JSON.parse(r.payload),
      serverSequence: r.serverSequence,
    }));

    return {
      operations,
      latestSequence: latestSeq?.serverSequence ?? 0,
    };
  }

  private async nextSequence(txManager: any): Promise<number> {
    const row = await txManager.findOne(ServerSequence, {
      where: { id: 1 },
    });
    if (!row) {
      const maxResult = await txManager
        .createQueryBuilder()
        .select('MAX(serverSequence)', 'max')
        .from(SyncLog, 'sync_log')
        .getRawOne();
      const initialMax = (maxResult?.max as number) ?? 0;
      const next = initialMax + 1;
      await txManager.insert(ServerSequence, { id: 1, current: next });
      return next;
    }
    const next = row.current + 1;
    await txManager.update(ServerSequence, 1, { current: next });
    return next;
  }

  private async logSync(
    txManager: any,
    seq: number,
    userId: string,
    entry: PushEntryDto,
    correctVersion: boolean,
    newVersion?: number,
  ) {
    let payload = entry.payload;
    if (correctVersion && newVersion != null) {
      const obj = JSON.parse(payload);
      obj.version = newVersion;
      payload = JSON.stringify(obj);
    }
    await txManager.insert(SyncLog, {
      serverSequence: seq,
      userId,
      entityType: entry.entityType,
      entityId: entry.entityId,
      operation: entry.operation,
      payload,
    });
  }

  private todoToSnake(todo: Todo) {
    return {
      id: todo.id,
      version: todo.version,
      userId: todo.userId,
      title: todo.title,
      description: todo.description,
      isDone: todo.isDone === 1,
      categoryId: todo.categoryId,
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt,
      deletedAt: todo.deletedAt,
    };
  }

  private categoryToCamel(category: Category) {
    return {
      id: category.id,
      version: category.version,
      userId: category.userId,
      name: category.name,
      description: category.description,
      color: category.color,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      deletedAt: category.deletedAt,
    };
  }

  private buildTodoInsert(id: string, userId: string, payload: any) {
    return {
      id,
      version: 1,
      userId,
      title: (payload.title as string) ?? '',
      description: (payload.description as string) ?? '',
      isDone: (payload.isDone as number) ?? 0,
      categoryId: (payload.categoryId as string) ?? null,
      createdAt: (payload.createdAt as string) ?? new Date().toISOString(),
      updatedAt: (payload.updatedAt as string) ?? new Date().toISOString(),
      deletedAt: (payload.deletedAt as string) ?? null,
    };
  }

  private buildTodoUpdate(payload: any, existing: Todo, newVersion: number) {
    return {
      version: newVersion,
      title: (payload.title as string) ?? existing.title,
      description: (payload.description as string) ?? existing.description,
      isDone: (payload.isDone as number) ?? existing.isDone,
      categoryId: (payload.categoryId as string) ?? existing.categoryId,
      updatedAt: (payload.updatedAt as string) ?? existing.updatedAt,
      deletedAt: payload.deletedAt != null ? (payload.deletedAt as string) : existing.deletedAt,
    };
  }

  private buildCategoryInsert(id: string, userId: string, payload: any) {
    return {
      id,
      version: 1,
      userId,
      name: (payload.name as string) ?? '',
      description: (payload.description as string) ?? '',
      color: (payload.color as string) ?? '#4CAF50',
      sortOrder: (payload.sortOrder as number) ?? 0,
      createdAt: (payload.createdAt as string) ?? new Date().toISOString(),
      updatedAt: (payload.updatedAt as string) ?? new Date().toISOString(),
      deletedAt: (payload.deletedAt as string) ?? null,
    };
  }

  private buildCategoryUpdate(payload: any, existing: Category, newVersion: number) {
    return {
      version: newVersion,
      name: (payload.name as string) ?? existing.name,
      description: (payload.description as string) ?? existing.description,
      color: (payload.color as string) ?? existing.color,
      sortOrder: (payload.sortOrder as number) ?? existing.sortOrder,
      updatedAt: (payload.updatedAt as string) ?? existing.updatedAt,
      deletedAt: payload.deletedAt != null ? (payload.deletedAt as string) : existing.deletedAt,
    };
  }
}
