import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, MoreThan } from 'typeorm';
import { ServerSequence } from './entities/server-sequence.entity';
import { SyncLog } from './entities/sync-log.entity';
import { Todo } from './entities/todo.entity';
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
    @InjectRepository(ProcessedEntry)
    private readonly processedEntryRepo: Repository<ProcessedEntry>,
    private readonly dataSource: DataSource,
  ) {}

  async handlePush(entries: PushEntryDto[], userId: string): Promise<PushResponseDto> {
    const results: SyncEntryResultDto[] = [];

    await this.dataSource.transaction(async (txManager) => {
      for (const entry of entries) {
        try {
          const processed = await txManager.findOne(ProcessedEntry, {
            where: { entryId: entry.id },
          });
          if (processed) {
            results.push(new SyncEntryResultDto({
              entryId: entry.id,
              outcome: 'accepted',
              serverSequence: processed.serverSequence,
            }));
            continue;
          }

          const seq = await this.nextSequence(txManager);
          const payload = JSON.parse(entry.payload);

          const existing = await txManager.findOne(Todo, {
            where: { id: entry.entityId },
          });

          if (existing && existing.userId !== userId) {
            await this.logSync(txManager, seq, userId, entry, false);
            results.push(new SyncEntryResultDto({
              entryId: entry.id,
              outcome: 'rejected',
              errorMessage: 'not owned by this user',
            }));
            continue;
          }

          if (entry.operation === 'delete') {
            if (existing) {
              const clientVersion = (payload.version as number) ?? 0;
              if (clientVersion < existing.version) {
                await this.logSync(txManager, seq, userId, entry, false);
                results.push(new SyncEntryResultDto({
                  entryId: entry.id,
                  outcome: 'conflicted',
                  serverPayload: JSON.stringify(this.todoToCamel(existing)),
                }));
                continue;
              }
            }
            if (existing) {
              await txManager.update(Todo, entry.entityId, {
                deletedAt: new Date().toISOString(),
              });
            }
            await this.logSync(txManager, seq, userId, entry, false);
          } else if (existing) {
            const clientVersion = (payload.version as number) ?? 0;
            if (clientVersion < existing.version) {
              await this.logSync(txManager, seq, userId, entry, false);
              results.push(new SyncEntryResultDto({
                entryId: entry.id,
                outcome: 'conflicted',
                serverPayload: JSON.stringify(this.todoToCamel(existing)),
              }));
              continue;
            }
            const newVersion = existing.version + 1;
            await txManager.update(Todo, entry.entityId, {
              version: newVersion,
              title: (payload.title as string) ?? existing.title,
              description: (payload.description as string) ?? existing.description,
              isDone: (payload.isDone as number) ?? existing.isDone,
              updatedAt: (payload.updatedAt as string) ?? existing.updatedAt,
              deletedAt: payload.deletedAt != null ? (payload.deletedAt as string) : existing.deletedAt,
            });
            await this.logSync(txManager, seq, userId, entry, true, newVersion);
          } else {
            await txManager.insert(Todo, {
              id: entry.entityId,
              version: 1,
              userId,
              title: (payload.title as string) ?? '',
              description: (payload.description as string) ?? '',
              isDone: (payload.isDone as number) ?? 0,
              createdAt: (payload.createdAt as string) ?? new Date().toISOString(),
              updatedAt: (payload.updatedAt as string) ?? new Date().toISOString(),
              deletedAt: (payload.deletedAt as string) ?? null,
            });
            await this.logSync(txManager, seq, userId, entry, true, 1);
          }

          await txManager.insert(ProcessedEntry, {
            entryId: entry.id,
            serverSequence: seq,
          });
          results.push(new SyncEntryResultDto({
            entryId: entry.id,
            outcome: 'accepted',
            serverSequence: seq,
          }));
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
    const seq = await txManager.findOne(ServerSequence, {
      where: { id: 1 },
    });
    if (!seq) {
      await txManager.insert(ServerSequence, { id: 1, current: 1 });
      return 1;
    }
    const next = seq.current + 1;
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

  private todoToCamel(todo: Todo) {
    return {
      id: todo.id,
      version: todo.version,
      userId: todo.userId,
      title: todo.title,
      description: todo.description,
      isDone: todo.isDone === 1,
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt,
      deletedAt: todo.deletedAt,
    };
  }
}
