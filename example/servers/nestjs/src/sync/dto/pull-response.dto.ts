export class RemoteOperationDto {
  entityType: string;
  entityId: string;
  operation: string;
  payload: string;
  serverSequence: number;
}

export class PullResponseDto {
  operations: RemoteOperationDto[];
  latestSequence: number;
}
