import { IsString, IsIn, IsInt, IsOptional } from 'class-validator';

export class SyncEntryResultDto {
  @IsString()
  entryId: string;

  @IsIn(['accepted', 'conflicted', 'rejected'])
  outcome: 'accepted' | 'conflicted' | 'rejected';

  @IsOptional()
  @IsInt()
  serverSequence?: number;

  @IsOptional()
  @IsString()
  serverPayload?: string;

  @IsOptional()
  @IsString()
  errorMessage?: string;

  constructor(init: {
    entryId: string;
    outcome: 'accepted' | 'conflicted' | 'rejected';
    serverSequence?: number;
    serverPayload?: string;
    errorMessage?: string;
  }) {
    this.entryId = init.entryId;
    this.outcome = init.outcome;
    this.serverSequence = init.serverSequence;
    this.serverPayload = init.serverPayload;
    this.errorMessage = init.errorMessage;
  }
}

export class PushResponseDto {
  results: SyncEntryResultDto[];

  constructor(results: SyncEntryResultDto[]) {
    this.results = results;
  }
}
